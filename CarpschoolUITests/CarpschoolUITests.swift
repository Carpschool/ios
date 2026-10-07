import XCTest

/// End-to-end tap flows against a live school server.
/// Inputs come from TEST_RUNNER_CS_* environment variables (see README):
/// CS_DRIVE (locked carpool drive id), CS_NEG2 (open chat with a driver proposal), CS_PASSWORD.
final class CarpschoolUITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for title in ["Allow While Using App", "Allow Once", "Not Now", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap(); return true
            }
            return false
        }
    }

    private func launch(_ who: String, route: String? = nil) {
        app?.terminate()
        app = XCUIApplication()
        app.launchEnvironment = [
            "CS_EMAIL": "\(who)+clerk_test@example.com",
            "CS_PASSWORD": env["CS_PASSWORD"] ?? "",
            "CS_SCHOOL": env["CS_SCHOOL"] ?? "kjt",
        ]
        if let route { app.launchEnvironment["CS_ROUTE"] = route }
        app.launch()
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    @discardableResult
    private func wait(_ e: XCUIElement, _ t: TimeInterval = 40, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(e.waitForExistence(timeout: t), "Missing \(e)", file: file, line: line)
        return e
    }

    func test1AddHome() {
        launch("csdriver", route: "homes")
        wait(app.navigationBars["Homes"])
        snap("homes-before")
        app.navigationBars["Homes"].buttons["Add Home"].tap()
        let search = wait(app.searchFields["Search address"])
        search.tap()
        search.typeText("Granville Island Public Market")
        let result = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Granville")).firstMatch
        wait(result, 20).tap()
        let label = wait(app.textFields["Label"])
        label.tap()
        if let v = label.value as? String, !v.isEmpty, v != "Label" { label.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count)) }
        label.typeText("UI Test Home")
        snap("add-home-filled")
        app.buttons["Save"].tap()
        let row = wait(app.staticTexts["UI Test Home"], 20)
        snap("homes-after-add")
        row.swipeLeft()
        wait(app.buttons["Delete"], 5).tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["UI Test Home"])
        wait(for: [gone], timeout: 15)
        snap("homes-after-delete")
    }

    func test2PinBoardDropoff() throws {
        let drive = try XCTUnwrap(env["CS_DRIVE"], "Set TEST_RUNNER_CS_DRIVE")
        launch("csrider", route: "ride:" + drive)
        wait(app.buttons["Show Boarding PIN"]).tap()
        let pinText = wait(app.staticTexts["boardingPIN"], 20)
        snap("rider-boarding-pin")
        let pin = pinText.label.filter(\.isNumber)
        XCTAssertEqual(pin.count, 4, "PIN label was \(pinText.label)")

        launch("csdriver", route: "ride:" + drive)
        wait(app.buttons["Enter PIN"]).tap()
        let field = wait(app.textFields["4 digit PIN"], 10)
        field.tap()
        field.typeText(pin)
        snap("driver-enter-pin")
        app.buttons["Board Rider"].tap()
        app.tap() // lets the interruption monitor answer a location prompt
        let drop = wait(app.buttons["Complete Drop-off"], 40)
        snap("driver-boarded")
        drop.tap()
        wait(app.buttons["Complete"], 10).tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["Complete Drop-off"])
        wait(for: [gone], timeout: 20)
        snap("driver-dropped-off")
    }

    func test3CounterOffer() throws {
        let neg = try XCTUnwrap(env["CS_NEG2"], "Set TEST_RUNNER_CS_NEG2")
        launch("csrider", route: "chat:" + neg)
        wait(app.buttons["Counter"]).tap()
        let send = wait(app.navigationBars.buttons["Send"], 15)
        snap("counter-sheet")
        send.tap()
        XCTAssertTrue(app.staticTexts["YOUR PROPOSAL"].waitForExistence(timeout: 20))
        snap("counter-sent")
    }

    func test4ReportAndBlock() throws {
        let neg = try XCTUnwrap(env["CS_NEG2"], "Set TEST_RUNNER_CS_NEG2")
        launch("csrider", route: "chat:" + neg)
        let safety = wait(app.buttons["Safety"])
        safety.tap()
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Report'")).firstMatch.tap()
        let reason = wait(app.textFields["What happened?"], 10)
        reason.typeText("UI test report, please ignore.")
        snap("report-filled")
        app.buttons["Send Report"].tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.textFields["What happened?"])
        wait(for: [closed], timeout: 15)
        snap("report-sent")

        safety.tap()
        wait(app.buttons["Block"], 5).tap()
        snap("block-confirm")
        wait(app.buttons["Block"].firstMatch, 5)
        app.sheets.buttons["Block"].exists ? app.sheets.buttons["Block"].tap() : app.buttons.matching(identifier: "Block").element(boundBy: app.buttons.matching(identifier: "Block").count - 1).tap()
        sleep(3)
        snap("after-block")
    }

    func test5PostDriveScrollsClear() {
        launch("csdriver", route: "newDrive")
        wait(app.navigationBars["Post a Drive"])
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        sleep(1)
        snap("post-drive-bottom")
    }
}
