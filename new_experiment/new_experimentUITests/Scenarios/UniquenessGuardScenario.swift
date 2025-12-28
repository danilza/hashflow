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
        let openResult = openFirstLevel(app, testCase: self)
        if !openResult.success {
            logger.fail(
                step: step3,
                description: "Open level",
                expected: "Level screen opened",
                actual: [openResult.failureReason, openResult.debugSummary].compactMap { $0 }.joined(separator: " | ")
            )
            return
        }
        logger.success(step: step3, description: "Open level")

        let step4 = logger.reserveStep()
        if !tapUITestPipeline(app) {
            logger.fail(step: step4, description: "Build pipeline A", expected: "UITEST pipeline applied", actual: "uitest_set_pipeline missing")
            return
        }
        logger.success(step: step4, description: "Build pipeline A")

        let step5 = logger.reserveStep()
        if !tapUITestRun(app) {
            logger.fail(step: step5, description: "Run pipeline A", expected: "UITEST run pipeline", actual: "uitest_run_pipeline missing")
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
        if !tapUITestRun(app) {
            logger.fail(step: step7, description: "Run pipeline A again", expected: "UITEST run pipeline", actual: "uitest_run_pipeline missing")
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
