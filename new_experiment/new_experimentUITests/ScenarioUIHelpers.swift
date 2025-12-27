import XCTest

func dismissIntroIfNeeded(_ app: XCUIApplication) {
    let closeButton = app.buttons["sheet_close"]
    if closeButton.waitForExistence(timeout: 2) {
        closeButton.tap()
    }
}

func openFirstLevel(_ app: XCUIApplication) -> Bool {
    let menuButton = app.buttons["menu_start_hacking"]
    if !menuButton.waitForExistence(timeout: 20) { return false }
    menuButton.tap()

    let header = app.staticTexts["УРОВНИ"]
    guard header.waitForExistence(timeout: 10) else { return false }

    let easyButton = app.buttons.containing(.staticText, identifier: "ОБУЧАЮЩИЕ").firstMatch
    if easyButton.exists {
        easyButton.tap()
    } else {
        let easyText = app.staticTexts["ОБУЧАЮЩИЕ"]
        if easyText.exists {
            easyText.tap()
        } else {
            return false
        }
    }

    let levelCell = app.staticTexts["Базовый уровень #1"]
    if !levelCell.waitForExistence(timeout: 10) { return false }
    levelCell.tap()

    if !ensurePipelineControlsVisible(app) { return false }
    let runButton = app.buttons["run_button"]
    return runButton.waitForExistence(timeout: 10)
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
    let addShift = app.buttons["pipeline_add_shift"]
    if addShift.waitForExistence(timeout: 2) { return true }
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
        for _ in 0..<8 {
            scrollView.swipeUp()
            if addShift.waitForExistence(timeout: 1) { return true }
        }
    }
    for _ in 0..<6 {
        app.swipeUp()
        if addShift.waitForExistence(timeout: 1) { return true }
    }
    return addShift.exists
}

func clearAndType(field: XCUIElement, value: String) {
    field.tap()
    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10)
    field.typeText(deleteString)
    field.typeText(value)
}
