import XCTest

func dismissIntroIfNeeded(_ app: XCUIApplication) {
    let closeButton = app.buttons["sheet_close"]
    if closeButton.waitForExistence(timeout: 2) {
        closeButton.tap()
    }
}

func openFirstLevel(_ app: XCUIApplication) -> Bool {
    let menuButton = findElement(app, id: "menu_start_hacking")
    if !menuButton.waitForExistence(timeout: 20) {
        for _ in 0..<4 {
            app.swipeUp()
            if menuButton.waitForExistence(timeout: 3) { break }
        }
    }
    guard menuButton.exists else { return false }
    menuButton.tap()

    let easyButton = findElement(app, id: "difficulty_easy")
    if !easyButton.waitForExistence(timeout: 10) {
        let header = app.staticTexts["УРОВНИ"]
        guard header.waitForExistence(timeout: 10) else { return false }
    }
    if easyButton.exists {
        easyButton.tap()
    } else {
        let easyFallback = app.buttons.containing(.staticText, identifier: "ОБУЧАЮЩИЕ").firstMatch
        if easyFallback.exists {
            easyFallback.tap()
        } else {
            return false
        }
    }

    let easyNav = app.navigationBars["Обучающие"]
    _ = easyNav.waitForExistence(timeout: 5)

    let levelButton = findElement(app, id: "level_row_1")
    if levelButton.waitForExistence(timeout: 10) {
        levelButton.tap()
    } else {
        let levelCell = app.staticTexts["Базовый уровень #1"]
        if !levelCell.waitForExistence(timeout: 10) { return false }
        levelCell.tap()
    }

    let infoPanel = app.otherElements["info_panel"]
    guard infoPanel.waitForExistence(timeout: 10) else { return false }
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
    if scrollView.exists, scrollView.isHittable, scrollView.frame.height > 1 {
        for _ in 0..<8 {
            scrollView.swipeUp()
            if addShift.waitForExistence(timeout: 1) { return true }
        }
    }
    for _ in 0..<8 {
        app.swipeUp()
        if addShift.waitForExistence(timeout: 1) { return true }
    }
    return addShift.exists
}

private func findElement(_ app: XCUIApplication, id: String) -> XCUIElement {
    app.descendants(matching: .any)[id]
}

func clearAndType(field: XCUIElement, value: String) {
    field.tap()
    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10)
    field.typeText(deleteString)
    field.typeText(value)
}
