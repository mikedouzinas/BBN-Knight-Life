//
//  BBNDailyUITests.swift
//  BBNDailyUITests
//
//  Created by Mike Veson on 9/6/21.
//

import XCTest

class BBNDailyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
        
        let collectionViewsQuery3 = app.collectionViews
        let cellsQuery = collectionViewsQuery3.cells
        cellsQuery.otherElements.containing(.staticText, identifier:"23").element.tap()
        
        let collectionViewsQuery = collectionViewsQuery3
        collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["28"]/*[[".cells.staticTexts[\"28\"]",".staticTexts[\"28\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["20"]/*[[".cells.staticTexts[\"20\"]",".staticTexts[\"20\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let collectionViewsQuery2 = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element(boundBy: 3).collectionViews
        collectionViewsQuery2.children(matching: .cell).element(boundBy: 9).staticTexts["7"].tap()
        
        let staticText = collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["16"]/*[[".cells.staticTexts[\"16\"]",".staticTexts[\"16\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        staticText.tap()
        collectionViewsQuery2.children(matching: .cell).element(boundBy: 31).staticTexts["29"].tap()
        collectionViewsQuery2.children(matching: .cell).element(boundBy: 32).staticTexts["30"].tap()
        
        let staticText2 = collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["17"]/*[[".cells.staticTexts[\"17\"]",".staticTexts[\"17\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        staticText2.tap()
        staticText2.tap()
        staticText2.tap()
        collectionViewsQuery2.children(matching: .cell).element(boundBy: 33).staticTexts["1"].swipeDown()
        staticText2.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["24"]/*[[".cells.staticTexts[\"24\"]",".staticTexts[\"24\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        staticText2.tap()
        staticText2.tap()
        staticText2.tap()
        staticText.tap()
        staticText2.tap()
        staticText2.tap()
        cellsQuery.otherElements.containing(.staticText, identifier:"17").element.tap()
        staticText2.tap()
        app.tabBars["Tab Bar"].children(matching: .other).element.children(matching: .other).element(boundBy: 3).tap()
//        app.swipeDown()
        app.swipeUp()
        app.swipeUp()
        
        let element2 = XCUIApplication().tabBars["Tab Bar"].children(matching: .other).element
        let element = element2.children(matching: .other).element(boundBy: 3)
        element.tap()
        element.tap()
        element.tap()
        element2.children(matching: .other).element(boundBy: 2).tap()
        element2.children(matching: .other).element(boundBy: 1).tap()
        
//        let tablesQuery = app.tables
//        tablesQuery.cells.containing(.staticText, identifier:"Monday Lunch").staticTexts["1st Lunch"].tap()
        
        let elementsQuery = app.sheets["Lunch"].scrollViews.otherElements
        elementsQuery.buttons["1st Lunch"].tap()
//        tablesQuery.buttons["Credits & Feedback"].tap()
        
        let cancelButton = elementsQuery.buttons["Cancel"]
        cancelButton.tap()
       
        app.children(matching: .window).element(boundBy: 0).tap()
//        tablesQuery.cells.containing(.staticText, identifier:"Wednesday Lunch").staticTexts["1st Lunch"].swipeDown()
        
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
