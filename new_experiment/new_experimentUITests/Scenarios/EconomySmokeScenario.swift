import XCTest

final class EconomySmokeScenario: XCTestCase {
    @MainActor
    func testEconomySmoke() async throws {
        let logger = ScenarioLogger("ECONOMY_SMOKE")
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
            user = try await factory.makeUser(prefix: "economy_smoke", wallet: env.walletAddress, dailyMoves: 10, credits: 0)
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
        let before: EconomySnapshot
        do {
            before = try await factory.fetchPlayerEconomy(userId: user.id)
        } catch {
            logger.fail(step: step3, description: "Read initial economy state", expected: "player_economy snapshot", actual: "\(error)")
            return
        }
        logger.success(step: step3, description: "Read initial economy state")

        let step4 = logger.reserveStep()
        let openResult = openFirstLevel(app, testCase: self)
        if !openResult.success {
            logger.fail(
                step: step4,
                description: "Open first level",
                expected: "Level screen opened",
                actual: [openResult.failureReason, openResult.debugSummary].compactMap { $0 }.joined(separator: " | ")
            )
            return
        }
        logger.success(step: step4, description: "Open first level")

        let step5 = logger.reserveStep()
        let pipelineReady = app.otherElements["uitest_pipeline_ready"]
        if !pipelineReady.waitForExistence(timeout: 20) {
            logger.fail(step: step5, description: "Perform one run", expected: "uitest_pipeline_ready", actual: "pipeline not applied")
            return
        }
        let successText = app.staticTexts["Уникальное решение!"]
        if !successText.waitForExistence(timeout: 40) {
            logger.fail(step: step5, description: "Perform one run", expected: "Success overlay", actual: "Unique solution overlay missing")
            return
        }
        logger.success(step: step5, description: "Perform one run")

        let step6 = logger.reserveStep()
        let after: EconomySnapshot
        do {
            after = try await factory.fetchPlayerEconomy(userId: user.id)
        } catch {
            logger.fail(step: step6, description: "Read economy state again", expected: "player_economy snapshot", actual: "\(error)")
            return
        }
        logger.success(step: step6, description: "Read economy state again")

        let step7 = logger.reserveStep()
        let movesDelta = before.dailyMovesLeft - after.dailyMovesLeft
        let creditsDelta = before.creditBalance - after.creditBalance
        let decreased = movesDelta > 0 || creditsDelta > 0
        if !decreased {
            logger.fail(
                step: step7,
                description: "Verify credits OR moves decreased",
                expected: "moves or credits decrease",
                actual: "before moves=\(before.dailyMovesLeft), after moves=\(after.dailyMovesLeft), before credits=\(before.creditBalance), after credits=\(after.creditBalance)"
            )
            return
        }
        if after.dailyMovesLeft < 0 || after.creditBalance < 0 {
            logger.fail(
                step: step7,
                description: "Verify credits OR moves decreased",
                expected: "balances non-negative",
                actual: "moves=\(after.dailyMovesLeft), credits=\(after.creditBalance)"
            )
            return
        }
        logger.success(step: step7, description: "Verify credits OR moves decreased")
    }
}
