import Foundation
import XCTest

struct OpenLevelResult {
    let success: Bool
    let failureReason: String?
    let debugSummary: String?

    static func ok() -> OpenLevelResult {
        OpenLevelResult(success: true, failureReason: nil, debugSummary: nil)
    }

    static func fail(_ reason: String, debug: String? = nil) -> OpenLevelResult {
        OpenLevelResult(success: false, failureReason: reason, debugSummary: debug)
    }
}

func dismissIntroIfNeeded(_ app: XCUIApplication) {
    let closeButton = app.buttons["sheet_close"]
    if closeButton.waitForExistence(timeout: 2) {
        closeButton.tap()
    }
}

func openFirstLevel(_ app: XCUIApplication, testCase: XCTestCase? = nil) -> OpenLevelResult {
    if !tapAnyElement(app, [
        app.buttons["menu_start_hacking"],
        app.otherElements["menu_start_hacking"],
        app.staticTexts["START HACKING"]
    ], timeout: 20) {
        return .fail("menu_start_hacking not found or not tappable", debug: levelDebugSummary(app))
    }

    if !waitForAny([
        app.otherElements["level_list_view"],
        app.staticTexts["УРОВНИ"],
        app.buttons["difficulty_easy"]
    ], timeout: 10) {
        return .fail("level list view not visible after START HACKING", debug: levelDebugSummary(app))
    }

    if !tapAnyElement(app, [
        app.buttons["difficulty_easy"],
        app.otherElements["difficulty_easy"],
        app.staticTexts["ОБУЧАЮЩИЕ"]
    ], timeout: 10) {
        return .fail("difficulty_easy not found or not tappable", debug: levelDebugSummary(app))
    }

    if !waitForAny([
        app.otherElements["level_difficulty_list_view"],
        app.navigationBars["Обучающие"]
    ], timeout: 10) {
        return .fail("difficulty list view not visible after choosing easy", debug: levelDebugSummary(app))
    }

    if !tapAnyElement(app, [
        app.buttons["level_row_1"],
        app.otherElements["level_row_1"],
        app.staticTexts["Базовый уровень #1"]
    ], timeout: 10) {
        return .fail("level_row_1 not found or not tappable", debug: levelDebugSummary(app))
    }

    if !waitForAny([
        app.otherElements["info_panel"],
        app.buttons["run_button"],
        app.otherElements["pipeline_section"]
    ], timeout: 10) {
        captureScreenshot(app, testCase: testCase, name: "open-level-no-level-view")
        return .fail("level_play_view not visible after level tap", debug: levelDebugSummary(app))
    }

    _ = waitForHittable(app.otherElements["info_panel"], timeout: 6)
    _ = waitForHittable(app.buttons["run_button"], timeout: 6)

    if !ensurePipelineControlsVisible(app) {
        let header = elementById(app, "pipeline_header")
        if header.exists {
            captureScreenshot(app, testCase: testCase, name: "pipeline-header-visible-no-controls")
            return .fail("pipeline_header visible but controls not hittable", debug: levelDebugSummary(app))
        }
        captureScreenshot(app, testCase: testCase, name: "pipeline-controls-missing")
        return .fail("pipeline controls not visible", debug: levelDebugSummary(app))
    }
    let runButton = app.buttons["run_button"]
    if !runButton.waitForExistence(timeout: 10) {
        captureScreenshot(app, testCase: testCase, name: "run-button-missing")
        return .fail("run_button missing", debug: levelDebugSummary(app))
    }
    return .ok()
}

func scrollToPipelineSection(_ app: XCUIApplication) -> Bool {
    let pipelineSection = app.otherElements["pipeline_section"]
    if pipelineSection.waitForExistence(timeout: 3) {
        return true
    }
    let scrollView = app.scrollViews.firstMatch
    guard scrollView.exists else { return pipelineSection.exists }
    for _ in 0..<6 {
        scrollView.swipeUp()
        if pipelineSection.waitForExistence(timeout: 2) {
            return true
        }
    }
    return pipelineSection.exists
}

func ensurePipelineControlsVisible(_ app: XCUIApplication) -> Bool {
    let header = elementById(app, "pipeline_header")
    if header.waitForExistence(timeout: 2), header.isHittable {
        let addShift = elementById(app, "pipeline_add_shift")
        if addShift.waitForExistence(timeout: 2) {
            if addShift.isHittable { return true }
            _ = scrollToMakeHittable(app, addShift)
            return addShift.isHittable
        }
    }
    let addShift = elementById(app, "pipeline_add_shift")
    if addShift.waitForExistence(timeout: 2) {
        if addShift.isHittable { return true }
        _ = scrollToMakeHittable(app, addShift)
        return addShift.isHittable
    }
    let scrollView = app.scrollViews["level_scroll_view"].exists ? app.scrollViews["level_scroll_view"] : app.scrollViews.firstMatch
    if scrollView.exists {
        if scrollView.isHittable, scrollView.frame.height > 1 {
            for _ in 0..<6 {
                scrollView.swipeDown()
                if addShift.waitForExistence(timeout: 1) { return addShift.isHittable }
            }
            for _ in 0..<6 {
                scrollView.swipeUp()
                if addShift.waitForExistence(timeout: 1) { return addShift.isHittable }
            }
        }
    }
    for _ in 0..<4 {
        app.swipeDown()
        if addShift.waitForExistence(timeout: 1) { return addShift.isHittable }
    }
    for _ in 0..<4 {
        app.swipeUp()
        if addShift.waitForExistence(timeout: 1) { return addShift.isHittable }
    }
    return addShift.exists && addShift.isHittable
}

private func tapAnyElement(_ app: XCUIApplication, _ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
    for element in elements {
        if tapElement(app, element, timeout: timeout) {
            return true
        }
    }
    return false
}

private func tapElement(_ app: XCUIApplication, _ element: XCUIElement, timeout: TimeInterval) -> Bool {
    if !element.waitForExistence(timeout: timeout) {
        return false
    }
    if !element.isHittable {
        _ = scrollToMakeHittable(app, element)
    }
    guard element.isHittable else { return false }
    element.tap()
    return true
}

private func scrollToMakeHittable(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
        for _ in 0..<6 {
            if element.isHittable { return true }
            scrollView.swipeUp()
        }
        for _ in 0..<3 {
            if element.isHittable { return true }
            scrollView.swipeDown()
        }
    }
    for _ in 0..<3 {
        if element.isHittable { return true }
        app.swipeUp()
    }
    return element.isHittable
}

private func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if elements.contains(where: { $0.exists }) {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
    return elements.contains(where: { $0.exists })
}

private func elementById(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
}

func tapById(_ app: XCUIApplication, id: String, timeout: TimeInterval = 5) -> Bool {
    tapElement(app, elementById(app, id), timeout: timeout)
}

private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if element.exists && element.isHittable {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
    return element.exists && element.isHittable
}

private func elementState(_ element: XCUIElement, name: String) -> String {
    let exists = element.exists ? "1" : "0"
    let hittable = element.isHittable ? "1" : "0"
    let enabled = element.isEnabled ? "1" : "0"
    return "\(name)=exists:\(exists),hittable:\(hittable),enabled:\(enabled)"
}

private func levelDebugSummary(_ app: XCUIApplication) -> String {
    let parts = [
        elementState(elementById(app, "info_panel"), name: "info_panel"),
        elementState(elementById(app, "run_button"), name: "run_button"),
        elementState(elementById(app, "pipeline_header"), name: "pipeline_header"),
        elementState(elementById(app, "pipeline_add_shift"), name: "pipeline_add_shift"),
        elementState(elementById(app, "level_scroll_view"), name: "level_scroll_view"),
        elementState(elementById(app, "pipeline_section"), name: "pipeline_section")
    ]
    return parts.joined(separator: " | ")
}

private func captureScreenshot(_ app: XCUIApplication, testCase: XCTestCase?, name: String) {
    guard let testCase else { return }
    let shot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: shot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
}

func clearAndType(field: XCUIElement, value: String) {
    field.tap()
    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10)
    field.typeText(deleteString)
    field.typeText(value)
}
