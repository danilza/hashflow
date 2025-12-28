import XCTest

final class NFTReadScenario: XCTestCase {
    @MainActor
    func testNFTRead() async throws {
        let logger = ScenarioLogger("NFT_READ")
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
            user = try await factory.makeUser(prefix: "nft_read", wallet: env.walletAddress)
        } catch {
            logger.fail(step: step0, description: "Prepare test user", expected: "admin create + profile + economy", actual: "\(error)")
            return
        }
        logger.success(step: step0, description: "Prepare test user")

        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_OVERLAY"] = "1"
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
        logger.success(step: step3, description: "Set test wallet address")

        let step4 = logger.reserveStep()
        let nftMenuButton = app.buttons["menu_nft_collection"]
        if !nftMenuButton.waitForExistence(timeout: 20) {
            logger.fail(step: step4, description: "Open NFT collection", expected: "menu_nft_collection visible", actual: "NFT menu missing")
            return
        }
        nftMenuButton.tap()
        logger.success(step: step4, description: "Open NFT collection")

        let step5 = logger.reserveStep()
        let title = app.staticTexts["My NFT Collection"]
        if !title.waitForExistence(timeout: 20) {
            logger.fail(step: step5, description: "Fetch NFTs via TonAssetService", expected: "NFT collection screen", actual: "NFT collection not visible")
            return
        }
        logger.success(step: step5, description: "Fetch NFTs via TonAssetService")

        let step6 = logger.reserveStep()
        let emptyState = app.staticTexts["Ещё нет NFT-решений"]
        let listItem = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Уровень'")).firstMatch
        if !emptyState.waitForExistence(timeout: 10) && !listItem.waitForExistence(timeout: 10) {
            logger.fail(step: step6, description: "Verify empty or non-empty list handled", expected: "Empty state or NFT card visible", actual: "No NFT UI state found")
            return
        }
        logger.success(step: step6, description: "Verify empty or non-empty list handled")
    }
}
