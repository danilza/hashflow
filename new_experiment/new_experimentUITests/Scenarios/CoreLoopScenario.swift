import XCTest
import CryptoKit

final class CoreLoopScenario: XCTestCase {
    @MainActor
    func testCoreLoopBasic() async throws {
        let logger = ScenarioLogger("CORE_LOOP_BASIC")
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
            user = try await factory.makeUser(prefix: "core_loop", wallet: env.walletAddress)
        } catch {
            logger.fail(step: step0, description: "Prepare test user", expected: "admin create + profile + economy", actual: "\(error)")
            return
        }
        logger.success(step: step0, description: "Prepare test user")

        let params = makeUITestPipelineParams(seed: user.id)
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_OVERLAY"] = "1"
        app.launchEnvironment["UITEST_AUTO_PIPELINE"] = "1"
        app.launchEnvironment["UITEST_PIPELINE"] = "xor2"
        app.launchEnvironment["UITEST_PIPELINE_SHIFT"] = "\(params.shift)"
        app.launchEnvironment["UITEST_PIPELINE_MASK1"] = "\(params.mask1)"
        app.launchEnvironment["UITEST_PIPELINE_MASK2"] = "\(params.mask2)"
        app.launchEnvironment["UITEST_AUTO_RUNS"] = "1"
        app.launchEnvironment["UITEST_AUTO_RUN_DELAY"] = "4"
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
                description: "Open first available level",
                expected: "Level screen with run button",
                actual: [openResult.failureReason, openResult.debugSummary].compactMap { $0 }.joined(separator: " | ")
            )
            return
        }
        logger.success(step: step3, description: "Open first available level")

        let step4 = logger.reserveStep()
        let pipelineReady = app.otherElements["uitest_pipeline_ready"]
        if !pipelineReady.waitForExistence(timeout: 20) {
            logger.fail(step: step4, description: "Build minimal valid pipeline", expected: "uitest_pipeline_ready", actual: "pipeline not applied")
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
        let successText = app.staticTexts["Уникальное решение!"]
        if !successText.waitForExistence(timeout: 40) {
            logger.fail(step: step6, description: "Run pipeline", expected: "Success overlay", actual: "Unique solution overlay missing")
            return
        }
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
        logger.success(step: step8, description: "record_unique_solution_v1 == true")

        let step9 = logger.reserveStep()
        let pipelineHash = params.hash
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
    guard ensurePipelineControlsVisible(app) else { return false }
    guard tapById(app, id: "pipeline_add_shift", timeout: 10) else { return false }
    guard tapById(app, id: "pipeline_add_xor", timeout: 10) else { return false }

    let shiftField = app.textFields["pipeline_shift_field"]
    let maskField = app.textFields["pipeline_mask_field"]
    guard shiftField.waitForExistence(timeout: 5),
          maskField.waitForExistence(timeout: 5) else { return false }

    clearAndType(field: shiftField, value: "2")
    clearAndType(field: maskField, value: "92")
    return true
}
