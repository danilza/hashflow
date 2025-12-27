import XCTest
import CryptoKit

final class UniquenessGuardScenario: XCTestCase {
    @MainActor
    func testUniquenessGuard() async throws {
        let logger = ScenarioLogger("UNIQUE_GUARD")
        let env = TestEnvironment()
        let envStep = logger.reserveStep()
        if let error = env.validateOrDescribeError() {
            logger.fail(step: envStep, description: "Validate test environment", expected: "UITEST_* secrets set", actual: error)
            return
        }
        logger.success(step: envStep, description: "Validate test environment")
        let factory = TestUserFactory(baseURL: env.supabaseURL, anonKey: env.anonKey, serviceKey: env.serviceKey)
        let step0 = logger.reserveStep()
        let user: TestUser
        do {
            user = try await factory.makeUser(prefix: "unique_guard", wallet: env.walletAddress)
        } catch {
            logger.fail(step: step0, description: "Prepare test user", expected: "admin create + profile + economy", actual: "\(error)")
            return
        }
        logger.success(step: step0, description: "Prepare test user")

        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_SUPABASE_URL"] = env.supabaseURL
        app.launchEnvironment["UITEST_SUPABASE_ANON_KEY"] = env.anonKey
        app.launchEnvironment["UITEST_SERVICE_KEY"] = env.serviceKey
        app.launchEnvironment["UITEST_EMAIL"] = user.email
        app.launchEnvironment["UITEST_PASSWORD"] = user.password
        app.launch()
        let step1 = logger.reserveStep()
        logger.success(step: step1, description: "Launch app")

        dismissIntroIfNeeded(app)

        let step2 = logger.reserveStep()
        if !app.buttons["profile_settings_button"].waitForExistence(timeout: 40) {
            logger.fail(step: step2, description: "Login", expected: "profile_settings_button visible", actual: "login timed out")
            return
        }
        logger.success(step: step2, description: "Login")

        let step3 = logger.reserveStep()
        if !openFirstLevel(app) {
            logger.fail(step: step3, description: "Open level", expected: "Level screen opened", actual: "Level screen missing")
            return
        }
        logger.success(step: step3, description: "Open level")

        let step4 = logger.reserveStep()
        if !configureLevelOnePipeline(app) {
            logger.fail(step: step4, description: "Build pipeline A", expected: "Shift=2 and Mask=92 applied", actual: "Pipeline fields missing")
            return
        }
        logger.success(step: step4, description: "Build pipeline A")

        let step5 = logger.reserveStep()
        if !tapRunButton(app) {
            logger.fail(step: step5, description: "Run pipeline A", expected: "run button exists", actual: "run button missing")
            return
        }
        logger.success(step: step5, description: "Run pipeline A")

        let step6 = logger.reserveStep()
        let successText = app.staticTexts["Уникальное решение!"]
        if !successText.waitForExistence(timeout: 30) {
            logger.fail(step: step6, description: "Expect unique = true", expected: "Success overlay", actual: "Unique overlay missing")
            return
        }
        logger.success(step: step6, description: "Expect unique = true")

        let step7 = logger.reserveStep()
        if !tapRunButton(app) {
            logger.fail(step: step7, description: "Run pipeline A again", expected: "run button exists", actual: "run button missing")
            return
        }
        logger.success(step: step7, description: "Run pipeline A again")

        let step8 = logger.reserveStep()
        let duplicateAlert = app.alerts["Повторный пайплайн"]
        if !duplicateAlert.waitForExistence(timeout: 20) {
            logger.fail(step: step8, description: "Expect unique = false", expected: "Duplicate alert shown", actual: "Duplicate alert missing")
            return
        }
        logger.success(step: step8, description: "Expect unique = false")

        let step9 = logger.reserveStep()
        let pipelineHash = levelOnePipelineHash()
        let count: Int
        do {
            count = try await factory.uniquePipelineCount(pipelineHash: pipelineHash)
        } catch {
            logger.fail(step: step9, description: "Verify duplicate not recorded", expected: "unique_pipelines lookup", actual: "\(error)")
            return
        }
        if count != 1 {
            logger.fail(step: step9, description: "Verify duplicate not recorded", expected: "unique_pipelines count = 1", actual: "unique_pipelines count = \(count)")
            return
        }
        logger.success(step: step9, description: "Verify duplicate not recorded")
    }
}

private func tapRunButton(_ app: XCUIApplication) -> Bool {
    let runButton = app.buttons["run_button"]
    guard runButton.waitForExistence(timeout: 10) else { return false }
    runButton.tap()
    return true
}

private func configureLevelOnePipeline(_ app: XCUIApplication) -> Bool {
    guard ensurePipelineControlsVisible(app) else { return false }
    let addShift = app.buttons["pipeline_add_shift"]
    let addXor = app.buttons["pipeline_add_xor"]
    guard addShift.waitForExistence(timeout: 10) else { return false }
    addShift.tap()
    guard addXor.waitForExistence(timeout: 10) else { return false }
    addXor.tap()

    let shiftField = app.textFields["pipeline_shift_field"]
    let maskField = app.textFields["pipeline_mask_field"]
    guard shiftField.waitForExistence(timeout: 5),
          maskField.waitForExistence(timeout: 5) else { return false }
    clearAndType(field: shiftField, value: "2")
    clearAndType(field: maskField, value: "92")
    return true
}

private func levelOnePipelineHash() -> String {
    struct Operation: Codable {
        let op: String
        let value: UInt32
    }
    struct Payload: Codable {
        let operations: [Operation]
    }
    let payload = Payload(operations: [
        Operation(op: "shift_left", value: 2),
        Operation(op: "xor", value: 92)
    ])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(payload)) ?? Data()
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}
