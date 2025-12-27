import XCTest
import CryptoKit

final class CoreLoopScenario: XCTestCase {
    @MainActor
    func testCoreLoopBasic() async throws {
        let logger = ScenarioLogger("CORE_LOOP_BASIC")
        let env = TestEnvironment()
        try env.validateOrThrow()
        let factory = TestUserFactory(baseURL: env.supabaseURL, anonKey: env.anonKey, serviceKey: env.serviceKey)
        let step0 = logger.reserveStep()
        let user: TestUser
        do {
            user = try await factory.makeUser(prefix: "core_loop", wallet: env.walletAddress)
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
            logger.fail(step: step3, description: "Open first available level", expected: "Level screen with run button", actual: "Level screen not opened")
            return
        }
        logger.success(step: step3, description: "Open first available level")

        let step4 = logger.reserveStep()
        if !configureLevelOnePipeline(app) {
            logger.fail(step: step4, description: "Build minimal valid pipeline", expected: "Shift=2 and Mask=92 applied", actual: "Pipeline fields missing")
            return
        }
        logger.success(step: step4, description: "Build minimal valid pipeline")

        let step5 = logger.reserveStep()
        let economyBefore: EconomySnapshot
        do {
            economyBefore = try await factory.fetchPlayerEconomy(userId: user.id)
        } catch {
            logger.fail(step: step5, description: "Read economy before run", expected: "player_economy snapshot", actual: "\(error)")
            return
        }
        logger.success(step: step5, description: "Read economy before run")

        let step6 = logger.reserveStep()
        let runButton = app.buttons["run"]
        if !runButton.waitForExistence(timeout: 10) {
            logger.fail(step: step6, description: "Run pipeline", expected: "run button visible", actual: "run button missing")
            return
        }
        runButton.tap()
        logger.success(step: step6, description: "Run pipeline")

        let step7 = logger.reserveStep()
        let economyAfter: EconomySnapshot
        do {
            economyAfter = try await factory.fetchPlayerEconomy(userId: user.id)
        } catch {
            logger.fail(step: step7, description: "consume_run_resources_v1", expected: "fetch player economy", actual: "\(error)")
            return
        }
        let movesDelta = economyBefore.dailyMovesLeft - economyAfter.dailyMovesLeft
        let creditsDelta = economyBefore.creditBalance - economyAfter.creditBalance
        if movesDelta <= 0 && creditsDelta <= 0 {
            logger.fail(
                step: step7,
                description: "consume_run_resources_v1",
                expected: "moves or credits decrease",
                actual: "before moves=\(economyBefore.dailyMovesLeft), after moves=\(economyAfter.dailyMovesLeft), before credits=\(economyBefore.creditBalance), after credits=\(economyAfter.creditBalance)"
            )
            return
        }
        logger.success(step: step7, description: "consume_run_resources_v1")

        let step8 = logger.reserveStep()
        let successText = app.staticTexts["Уникальное решение!"]
        if !successText.waitForExistence(timeout: 30) {
            logger.fail(step: step8, description: "record_unique_solution_v1 == true", expected: "Success overlay", actual: "Unique solution overlay missing")
            return
        }
        logger.success(step: step8, description: "record_unique_solution_v1 == true")

        let step9 = logger.reserveStep()
        let pipelineHash = levelOnePipelineHash()
        let count: Int
        do {
            count = try await factory.uniquePipelineCount(pipelineHash: pipelineHash)
        } catch {
            logger.fail(step: step9, description: "Verify level marked as completed", expected: "unique_pipelines lookup", actual: "\(error)")
            return
        }
        if count != 1 {
            logger.fail(step: step9, description: "Verify level marked as completed", expected: "unique_pipelines count = 1", actual: "unique_pipelines count = \(count)")
            return
        }
        logger.success(step: step9, description: "Verify level marked as completed")
    }
}

private func configureLevelOnePipeline(_ app: XCUIApplication) -> Bool {
    let addShift = app.buttons["Add Shift"]
    let addXor = app.buttons["Add XOR"]
    guard addShift.waitForExistence(timeout: 10) else { return false }
    addShift.tap()
    guard addXor.waitForExistence(timeout: 10) else { return false }
    addXor.tap()

    let fields = app.textFields
    guard fields.count >= 2 else { return false }
    let shiftField = fields.element(boundBy: 0)
    let maskField = fields.element(boundBy: 1)
    guard shiftField.exists, maskField.exists else { return false }

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
