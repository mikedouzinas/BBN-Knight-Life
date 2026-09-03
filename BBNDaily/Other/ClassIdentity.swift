//
//  ClassIdentity.swift
//  BBNDaily
//
//  HQ-656. Two students scanning the same class must end up in the same class, and today
//  that is not guaranteed.
//
//  A class document's ID *is* its text: `Subject~Teacher~Room~Block`. So "Ms. Lieberman" and
//  "Ms Lieberman" are two different classes, and so are "285" and "Room 285". Typed by hand
//  that produced 378 class records covering 189 distinct subject names, which is far more
//  than BB&N offers - the excess is duplicates, and duplicates split rosters (HQ-877).
//
//  Scanning makes that worse in a specific way, because it removes the one thing that used to
//  slow it down. Typing is serial and rare; scanning is fast and happens to everybody in the
//  same week. A whole grade can create the same class within minutes of each other.
//
//  TWO PROPERTIES ARE NEEDED, AND THEY ARE DIFFERENT PROBLEMS.
//
//  1. DETERMINISM. The same real class must always produce the same key, whatever wording the
//     model returned. That is `canonicalClassKey`.
//
//     This is also what makes concurrency safe, and the reason is worth stating plainly: the
//     key IS the document ID, so two students who compute the same key are writing to the same
//     document. Firestore merges them. There is no race to lose, no lock to take, and no
//     coordination between the two phones. Fifty students scanning at once converge on one
//     document precisely because the ID was derived from the content rather than generated.
//
//     Nondeterminism is the entire bug. Fix the key and the concurrency takes care of itself.
//
//  2. RECOGNITION. A class that already exists - typed by hand last year, or created by a
//     student whose sheet worded it differently - must be JOINED rather than recreated. A
//     canonical key alone cannot do this, because the existing document is not in canonical
//     form. That is `matchesExistingClass`, used to search the block before creating.
//
//  Without the course catalogue (HQ-877) this is as far as determinism can go: it makes the
//  app agree with itself. The catalogue is what would make it agree with the school, by
//  replacing free text with a chosen ID. These functions are the bridge until then, and they
//  stay useful afterwards for anything typed by hand.
//

import Foundation

enum ClassIdentity {

    /// The subject written for a block the sheet shows as open. One spelling, everywhere.
    ///
    /// Sheets say "Unscheduled", "Study Hall", "Free Period" and simply blank. Left alone
    /// those become four different class documents for the same empty block, which defeats
    /// the reason for recording a free block at all - seeing who else is free with you.
    static let freeSubject = "Free"

    // MARK: - Determinism

    /// The key two students scanning the same class both arrive at.
    ///
    /// Formatting only. It never changes which words are in a name, because this string is
    /// also what the student reads: `String.getValues()` splits it back apart to render the
    /// class, so lowercasing it here would show them "precalculus".
    static func canonicalClassKey(subject: String, teacher: String, room: String, block: String) -> String {
        let cleanBlock = block.trimmingCharacters(in: .whitespaces).uppercased()
        let cleanSubject = canonicalSubject(subject)

        // A free block is the same free block for everyone, so it carries no teacher and no
        // room. Letting a stray room through would split "Free" into one roster per room.
        if isFree(cleanSubject) {
            return "\(freeSubject)~~~\(cleanBlock)"
        }

        // A supervised study period keeps its room and drops its supervisor. The room is where
        // the student has to be; the supervisor is whoever is covering that day. One sheet
        // printed Study 9 in room 372 with Mr. Moccia on Wednesday and Ms. Rose on Friday, so
        // a key carrying the teacher makes a second study hall out of the same room.
        let cleanRoom = canonicalRoom(room)
        if isStudyHall(cleanSubject) && !cleanRoom.isEmpty {
            return "\(cleanSubject)~~\(cleanRoom)~\(cleanBlock)"
        }
        return "\(cleanSubject)~\(canonicalTeacher(teacher))~\(cleanRoom)~\(cleanBlock)"
    }

    /// Collapse runs of whitespace, trim, and drop stray edge punctuation. Case is left alone.
    static func canonicalSubject(_ subject: String) -> String {
        let collapsed = collapseWhitespace(subject)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-–—"))
    }

    /// Normalise the honorific, and the CASE of a name that carries no case information.
    ///
    /// "Ms Lieberman", "ms. lieberman" and "MS. LIEBERMAN" are one teacher, and they have to
    /// produce one string rather than three, because this string is the document id - see the
    /// note at the top of the file about why byte-equality is what makes concurrent scans
    /// safe. Fixing only the honorific left "Ms. ROSE", "Ms. Rose" and "Ms. rose" as three
    /// separate classes, which the concurrency test caught.
    ///
    /// A word that is ALL CAPS or all lowercase carries no case information: nobody writes a
    /// surname that way on purpose, so it is safe to title-case. A word with interior capitals
    /// is left exactly alone, because that is somebody's actual name and "McDonald",
    /// "O'Brien", "DiAngelo" and "van Dijk" are all things this must not rewrite.
    ///
    /// Spelling is never touched. This cannot tell a typo from a real name, and guessing would
    /// merge two different teachers - which is worse than a duplicate, because it puts a
    /// student on a roster they are not in.
    static func canonicalTeacher(_ teacher: String) -> String {
        let collapsed = collapseWhitespace(teacher)
        guard !collapsed.isEmpty else { return "" }

        var parts = collapsed.split(separator: " ").map(String.init)
        let titles: [String: String] = [
            "ms": "Ms.", "mrs": "Mrs.", "mr": "Mr.", "dr": "Dr.",
            "mx": "Mx.", "prof": "Prof.", "coach": "Coach",
        ]
        let firstBare = parts[0].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let hasTitle = parts.count > 1 && titles[firstBare] != nil
        if hasTitle { parts[0] = titles[firstBare]! }

        let nameRange = (hasTitle ? 1 : 0)..<parts.count
        for i in nameRange {
            parts[i] = normalizedNameCase(parts[i])
        }
        return parts.joined(separator: " ")
    }

    /// Just the room. "Room 285", "Rm. 285" and "#285" are all 285.
    static func canonicalRoom(_ room: String) -> String {
        var value = collapseWhitespace(room)
        guard !value.isEmpty else { return "" }
        for prefix in ["room ", "rm. ", "rm ", "#"] {
            if value.lowercased().hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                break
            }
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
    }

    static func isFree(_ subject: String) -> Bool {
        let key = comparisonKey(subject)
        return ["free", "freeperiod", "freeblock", "unscheduled", "unassigned",
                "studyhall", "study", "open", "none", "na", "noclass", "flex"].contains(key)
    }

    /// A supervised study period: "Study 9", "Study Hall 11", and the bare forms.
    ///
    /// Different from a free block, and only when the sheet gives it a room - see
    /// `canonicalClassKey`. The grade suffix stays part of the name because Study 9 and Study 11
    /// are different rooms full of different students. Anchored, so the real courses "Study
    /// Skills" and "Advanced Study Hall Design" are not swept in.
    static func isStudyHall(_ subject: String) -> Bool {
        let key = comparisonKey(subject)
        for suffix in ["", "9", "10", "11", "12"] {
            if key == "study\(suffix)" || key == "studyhall\(suffix)" { return true }
        }
        return false
    }

    // MARK: - Recognition

    /// Everything that is not a letter or a digit, removed, and lowercased. For COMPARING
    /// only - never stored, never shown.
    static func comparisonKey(_ value: String) -> String {
        return value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// The teacher's surname, lowercased, with the honorific dropped.
    ///
    /// The surname is the part that identifies a teacher and the part that survives every
    /// wording, so it is what two records are compared on.
    static func teacherSurnameKey(_ teacher: String) -> String {
        let collapsed = collapseWhitespace(teacher)
        guard let last = collapsed.split(separator: " ").last else { return "" }
        return comparisonKey(String(last))
    }

    /// Is `existingKey` (a `Subject~Teacher~Room~Block` document id already in Firestore) the
    /// same real class as the one just scanned?
    ///
    /// Room is deliberately NOT compared. A class keeps its identity when it moves room, two
    /// students' sheets can disagree about the room, and one of them is often blank. Matching
    /// on room is how one class becomes three.
    static func matchesExistingClass(existingKey: String, subject: String, teacher: String, block: String) -> Bool {
        let parts = existingKey.components(separatedBy: "~")
        guard parts.count == 4 else { return false }

        let existingBlock = parts[3].trimmingCharacters(in: .whitespaces).uppercased()
        guard existingBlock == block.trimmingCharacters(in: .whitespaces).uppercased() else { return false }

        let existingSubject = parts[0]
        // "N/A" is a display convention applied when a key is parsed, never a real value.
        let existingTeacher = parts[1] == "N/A" ? "" : parts[1]

        // Free blocks match each other and nothing else.
        if isFree(subject) || isFree(existingSubject) {
            return isFree(subject) && isFree(existingSubject)
        }

        guard comparisonKey(existingSubject) == comparisonKey(subject) else { return false }

        // A record with no teacher is the same class as one that names a teacher - somebody
        // just left it blank. Two records naming DIFFERENT teachers are two sections, and
        // must stay apart, because that is the difference the roster exists to capture.
        let scannedSurname = teacherSurnameKey(teacher)
        let existingSurname = teacherSurnameKey(existingTeacher)
        if scannedSurname.isEmpty || existingSurname.isEmpty { return true }
        return scannedSurname == existingSurname
    }

    // MARK: -

    /// Title-case a word ONLY when it carries no case information of its own.
    ///
    /// "ROSE" and "rose" become "Rose". "McDonald", "O'Brien" and "van" are returned untouched,
    /// because a word whose capitals are not simply first-letter-only is one somebody wrote
    /// deliberately, and rewriting it would be both wrong on screen and, worse, a second
    /// spelling of a teacher who already exists.
    private static func normalizedNameCase(_ word: String) -> String {
        let letters = word.filter { $0.isLetter }
        guard !letters.isEmpty else { return word }

        // Nobiliary particles are lowercase on purpose: "van Dijk", "de Souza", "von Trapp".
        // They are all-lowercase, so the rule below would capitalise them and turn one
        // teacher into two spellings. Left alone in whatever case they arrive.
        let particles: Set<String> = [
            "van", "von", "de", "del", "della", "di", "da", "das", "dos", "du",
            "la", "le", "den", "der", "ter", "ten", "bin", "ibn", "al", "el", "y",
        ]
        if particles.contains(letters.lowercased()) { return word.lowercased() }

        let allUpper = letters.allSatisfy { $0.isUppercase }
        let allLower = letters.allSatisfy { $0.isLowercase }
        guard allUpper || allLower else { return word }

        // Capitalise the first letter and lowercase the rest, leaving punctuation in place so
        // a hyphenated or apostrophed surname keeps its shape.
        var seenFirstLetter = false
        return String(word.map { ch -> Character in
            guard ch.isLetter else { return ch }
            if !seenFirstLetter {
                seenFirstLetter = true
                return Character(ch.uppercased())
            }
            return Character(ch.lowercased())
        })
    }

    private static func collapseWhitespace(_ value: String) -> String {
        return value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
