//
//  PlannerKindStyle.swift
//  BBNDaily
//
//  HQ-2182. How each kind of planner item looks: its color, its symbol, and its words. One
//  place, so a test, a homework or a game is drawn the same everywhere it appears.
//
//  Red for tests, blue for homework, green for sports, yellow for appointments.
//
//  Three things a color alone would get wrong, and what is done about each:
//
//  - COLOR IS NEVER THE ONLY SIGNAL. Red and green are the classic color-blind pair, so every
//    kind also has its own symbol and its own word. A student who cannot tell the colors apart
//    loses nothing.
//  - YELLOW. Ordinary yellow (#F9AB00) is 1.93:1 against white, well under the 3:1 that a
//    graphical indicator needs, so on a light background it is nearly invisible. Light mode uses
//    a deeper gold (#C67A00, 3.40:1) that still reads as yellow; dark mode uses bright yellow,
//    which is 8.4:1 against the navy. Because it is a fill and a symbol, never text, it does not
//    need the 4.5:1 that text would.
//  - DARK MODE. Each color is a named asset with a light and a dark variant (HQ-629: no
//    hardcoded colors). PlannerKindStyleTests checks the contrast of all eight against the real
//    background, so a color picked later by eye cannot quietly fail.
//

import UIKit

extension PlannerKind {

    /// The named color in Assets.xcassets. Never use these four colors by literal anywhere else.
    var colorName: String {
        switch self {
        case .test: return "PlannerTest"
        case .homework: return "PlannerHomework"
        case .sports: return "PlannerSports"
        case .appointment: return "PlannerAppointment"
        }
    }

    var color: UIColor {
        // Falls back to a visible color rather than clear: a missing asset should look wrong,
        // not make an item vanish. PlannerKindStyleTests fails if any of the four is missing.
        UIColor(named: colorName) ?? .systemGray
    }

    /// SF Symbol names available from iOS 15, the app's minimum.
    var symbolName: String {
        switch self {
        case .test: return "doc.text"
        case .homework: return "book"
        case .sports: return "sportscourt"
        case .appointment: return "calendar"
        }
    }

    var symbol: UIImage? {
        UIImage(systemName: symbolName) ?? UIImage(systemName: "circle.fill")
    }

    /// What the kind means, for the legend.
    var meaning: String {
        switch self {
        case .test: return "Tests and quizzes"
        case .homework: return "Homework and assignments"
        case .sports: return "Practices and games"
        case .appointment: return "Appointments and other commitments"
        }
    }
}
