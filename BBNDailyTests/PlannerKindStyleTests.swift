//
//  PlannerKindStyleTests.swift
//  BBNDailyTests
//
//  HQ-2182. The planner's colors are an accessibility claim, not a taste: yellow on white is
//  1.93:1 and effectively invisible, red and green are the color-blind pair. These tests measure
//  rather than trust the eye, against the app's real background in both appearances, so a color
//  swapped in later cannot quietly fail.
//

import XCTest
@testable import BBNDaily

final class PlannerKindStyleTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    private func rgb(_ color: UIColor, _ traits: UITraitCollection) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    /// WCAG relative luminance.
    private func luminance(_ color: UIColor, _ traits: UITraitCollection) -> CGFloat {
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let (r, g, b) = rgb(color, traits)
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor, _ traits: UITraitCollection) -> CGFloat {
        let la = luminance(a, traits), lb = luminance(b, traits)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testEveryKindHasItsNamedColorInTheAssetCatalog() {
        for kind in PlannerKind.allCases {
            XCTAssertNotNil(UIColor(named: kind.colorName), "\(kind.colorName) is missing from Assets.xcassets")
        }
    }

    /// The point of coloring at all: four kinds, four different colors, in both appearances.
    func testTheFourColorsAreDistinctInBothAppearances() {
        for traits in [light, dark] {
            let colors = PlannerKind.allCases.map { rgb($0.color, traits) }
            for i in 0..<colors.count {
                for j in (i + 1)..<colors.count {
                    let d = abs(colors[i].r - colors[j].r) + abs(colors[i].g - colors[j].g) + abs(colors[i].b - colors[j].b)
                    XCTAssertGreaterThan(d, 0.5, "\(PlannerKind.allCases[i]) and \(PlannerKind.allCases[j]) look alike")
                }
            }
        }
    }

    /// 3:1 is the minimum for a graphical indicator (the stripe, the symbol). The test that would
    /// have caught ordinary yellow, which is 1.93:1 on white.
    func testEveryColorIsVisibleAgainstTheRealBackgroundInBothAppearances() throws {
        let background = try XCTUnwrap(UIColor(named: "background"))
        for traits in [light, dark] {
            for kind in PlannerKind.allCases {
                let ratio = contrast(kind.color, background, traits)
                XCTAssertGreaterThanOrEqual(ratio, 3.0,
                    "\(kind) is \(String(format: "%.2f", ratio)):1 against the background in \(traits.userInterfaceStyle == .dark ? "dark" : "light") mode")
            }
        }
    }

    /// Guard the guard: prove the contrast helper really would reject ordinary yellow on white.
    func testTheContrastCheckWouldHaveRejectedOrdinaryYellow() {
        let yellow = UIColor(red: 0xF9 / 255, green: 0xAB / 255, blue: 0x00 / 255, alpha: 1)
        XCTAssertLessThan(contrast(yellow, .white, light), 3.0)
    }

    func testColorIsNeverTheOnlySignal() {
        let names = PlannerKind.allCases.map { $0.symbolName }
        XCTAssertEqual(Set(names).count, names.count, "every kind needs its own symbol")
        let labels = PlannerKind.allCases.map { $0.label }
        XCTAssertEqual(Set(labels).count, labels.count, "every kind needs its own word")
        for kind in PlannerKind.allCases {
            XCTAssertNotNil(UIImage(systemName: kind.symbolName), "\(kind.symbolName) does not exist on this OS")
            XCTAssertFalse(kind.meaning.isEmpty)
        }
    }

    /// The calendar header is dark navy whatever the appearance, so its dots need the dark
    /// variants. Checked against the app's dark background, which is lighter than the header: a
    /// color that passes here passes on the darker header too.
    func testCalendarDotsAreVisibleOnTheDarkHeaderEvenInLightMode() throws {
        let darkBackground = try XCTUnwrap(UIColor(named: "background"))
        for kind in PlannerKind.allCases {
            XCTAssertGreaterThanOrEqual(contrast(kind.calendarDotColor, darkBackground, dark), 3.0, "\(kind) dot on dark")
            XCTAssertEqual(rgb(kind.calendarDotColor, light).r, rgb(kind.color, dark).r, accuracy: 0.01,
                           "\(kind) dot should be the dark variant even when resolved in light mode")
        }
    }

    func testTheRequestedColorsAreTheRequestedHues() {
        // Red tests, blue homework, green sports, yellow appointments: check the dominant channel
        // so a swap of two assets is caught.
        func hue(_ kind: PlannerKind) -> CGFloat {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            kind.color.resolvedColor(with: light).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return h * 360
        }
        XCTAssertTrue(hue(.test) < 20 || hue(.test) > 340, "tests should be red, hue \(hue(.test))")
        XCTAssertTrue((200...235).contains(hue(.homework)), "homework should be blue, hue \(hue(.homework))")
        XCTAssertTrue((110...150).contains(hue(.sports)), "sports should be green, hue \(hue(.sports))")
        XCTAssertTrue((30...55).contains(hue(.appointment)), "appointments should be yellow/gold, hue \(hue(.appointment))")
    }
}
