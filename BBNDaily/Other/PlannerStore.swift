//
//  PlannerStore.swift
//  BBNDaily
//
//  HQ-2180. Reads and writes a student's planner at users/{uid}/planner/{itemId}.
//
//  Three rules this file holds to, each learned the hard way elsewhere in this app:
//
//  1. Every write reports its outcome. HQ-656's first save loop passed `{ _ in }` as its
//     completion, so a refused write carried on and the screen still said "saved". A student
//     who is told a test is on their planner when it is not is worse off than one who is told
//     nothing, so a failure here always reaches the caller.
//  2. No uid, no write. `LoginVC.updateField` guards the same way: an empty uid interpolates to
//     `document("")`, which Firestore treats as a programmer error and crashes on, and nothing
//     guarantees the account has finished loading when a student taps Save.
//  3. A document this build cannot read is skipped, not fatal. A newer app may write a kind this
//     one has never heard of; one unreadable item must not blank the whole planner.
//

import Foundation
import FirebaseFirestore

enum PlannerError: Error {
    case notSignedIn
    case invalid(PlannerValidationError)
    case firestore(Error)

    /// A sentence for the student.
    var message: String {
        switch self {
        case .notSignedIn: return "Please sign out and back in to fix your account."
        case .invalid(let reason): return reason.message
        case .firestore(let error): return PlannerError.studentMessage(for: error)
        }
    }

    /// Why a Firestore call failed, in words that point at the real cause. "Check your connection"
    /// is right when the network is the problem and exactly wrong when the server refused the
    /// write, which sends a student hunting for a connection fault that does not exist. Found on
    /// a real device: the first build, run before the rules were deployed, told every student to
    /// check their connection.
    static func studentMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain {
            switch FirestoreErrorCode.Code(rawValue: nsError.code) {
            case .permissionDenied?, .unauthenticated?:
                return "Your planner isn't available right now. Please try again later."
            default:
                break
            }
        }
        return "Couldn't reach your planner. Check your connection and try again."
    }
}

final class PlannerStore {
    static let shared = PlannerStore()

    private let db: Firestore
    private let currentUID: () -> String?

    init(db: Firestore = Firestore.firestore(),
         currentUID: @escaping () -> String? = { LoginVC.blocks["uid"] as? String }) {
        self.db = db
        self.currentUID = currentUID
    }

    /// The signed-in student's uid, or nil if the account has not loaded.
    private func uid() -> String? {
        guard let uid = currentUID(), !uid.isEmpty else { return nil }
        return uid
    }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("planner")
    }

    /// A fresh id for a new item. Generated client-side (no network) so an item has an identity
    /// before it is saved, which a step needs in order to name its parent.
    func newID() -> String? {
        guard let uid = uid() else { return nil }
        return collection(uid).document().documentID
    }

    /// Creates the item, or replaces it if its id already exists. Replaces rather than merges, so
    /// clearing an optional field (removing a due time) actually removes it.
    func save(_ item: PlannerItem, completion: @escaping (Result<Void, PlannerError>) -> Void) {
        if let reason = item.validationError() {
            completion(.failure(.invalid(reason)))
            return
        }
        guard let uid = uid() else {
            completion(.failure(.notSignedIn))
            return
        }
        collection(uid).document(item.id).setData(item.firestoreData) { error in
            if let error = error {
                print("PlannerStore.save(\(item.id)) failed: \(error)")
                completion(.failure(.firestore(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Saves several items as one atomic write: all of them or none. A split into steps and a change
    /// that moves a parent's steps must not be able to stop halfway, which would leave a plan that
    /// contradicts itself. Firestore allows 500 writes in a batch; a parent has at most
    /// PlannerSteps.maxSteps steps, so this never comes close.
    func saveAll(_ items: [PlannerItem], completion: @escaping (Result<Void, PlannerError>) -> Void) {
        guard !items.isEmpty else { completion(.success(())); return }
        for item in items {
            if let reason = item.validationError() {
                completion(.failure(.invalid(reason)))
                return
            }
        }
        guard let uid = uid() else {
            completion(.failure(.notSignedIn))
            return
        }
        let batch = db.batch()
        for item in items { batch.setData(item.firestoreData, forDocument: collection(uid).document(item.id)) }
        batch.commit { error in
            if let error = error {
                print("PlannerStore.saveAll(\(items.count)) failed: \(error)")
                completion(.failure(.firestore(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Deletes several items as one atomic write: a parent and its steps go together or not at all.
    func deleteAll(ids: [String], completion: @escaping (Result<Void, PlannerError>) -> Void) {
        guard !ids.isEmpty else { completion(.success(())); return }
        guard !ids.contains(where: { $0.isEmpty }) else {
            completion(.failure(.invalid(.missingID)))
            return
        }
        guard let uid = uid() else {
            completion(.failure(.notSignedIn))
            return
        }
        let batch = db.batch()
        for id in ids { batch.deleteDocument(collection(uid).document(id)) }
        batch.commit { error in
            if let error = error {
                print("PlannerStore.deleteAll(\(ids.count)) failed: \(error)")
                completion(.failure(.firestore(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    /// A fresh id for each of `count` new items, with no network.
    func newIDs(_ count: Int) -> [String]? {
        guard let uid = uid() else { return nil }
        return (0..<count).map { _ in collection(uid).document().documentID }
    }

    func delete(id: String, completion: @escaping (Result<Void, PlannerError>) -> Void) {
        guard let uid = uid() else {
            completion(.failure(.notSignedIn))
            return
        }
        guard !id.isEmpty else {
            // Same crash as an empty uid: document("") is a programmer error, not a failed write.
            completion(.failure(.invalid(.missingID)))
            return
        }
        collection(uid).document(id).delete { error in
            if let error = error {
                print("PlannerStore.delete(\(id)) failed: \(error)")
                completion(.failure(.firestore(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Items due from `startDay` through `endDay`, inclusive, soonest first. Days are the stored
    /// "yyyy-MM-dd" form, so this is one range on one field: no composite index, and one read for a
    /// whole visible month rather than one per day cell.
    func items(from startDay: String, through endDay: String,
               completion: @escaping (Result<[PlannerItem], PlannerError>) -> Void) {
        guard PlannerItem.date(fromDay: startDay) != nil, PlannerItem.date(fromDay: endDay) != nil else {
            completion(.failure(.invalid(.badDate)))
            return
        }
        guard let uid = uid() else {
            completion(.failure(.notSignedIn))
            return
        }
        collection(uid)
            .whereField("dueDate", isGreaterThanOrEqualTo: startDay)
            .whereField("dueDate", isLessThanOrEqualTo: endDay)
            .order(by: "dueDate")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("PlannerStore.items failed: \(error)")
                    completion(.failure(.firestore(error)))
                    return
                }
                let items = (snapshot?.documents ?? []).compactMap { document -> PlannerItem? in
                    let item = PlannerItem(id: document.documentID, data: document.data())
                    if item == nil { print("PlannerStore: skipped unreadable item \(document.documentID)") }
                    return item
                }
                completion(.success(items))
            }
    }
}
