import XCTest

final class AuthSmokeScenario: XCTestCase {
    @MainActor
    func testAuthSmoke() async throws {
        let logger = ScenarioLogger("AUTH_SMOKE")
        let env = TestEnvironment()
        try env.validateOrThrow()
        let factory = TestUserFactory(baseURL: env.supabaseURL, anonKey: env.anonKey, serviceKey: env.serviceKey)

        let step0 = logger.reserveStep()
        let latestBefore: String?
        do {
            latestBefore = try await factory.fetchLatestAuthUserID()
        } catch {
            logger.fail(step: step0, description: "Snapshot latest auth user", expected: "admin users list fetch", actual: "\(error)")
            return
        }
        logger.success(step: step0, description: "Snapshot latest auth user")

        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_SUPABASE_URL"] = env.supabaseURL
        app.launchEnvironment["UITEST_SERVICE_KEY"] = env.serviceKey
        app.launch()
        let step1 = logger.reserveStep()
        logger.success(step: step1, description: "Launch app")

        dismissIntroIfNeeded(app)

        let anonButton = app.buttons["auth_anon_button"]
        let step2 = logger.reserveStep()
        if !anonButton.waitForExistence(timeout: 25) {
            logger.fail(step: step2, description: "Anonymous login", expected: "auth_anon_button present", actual: "auth_anon_button missing")
            return
        }
        anonButton.tap()
        logger.success(step: step2, description: "Anonymous login")

        let profileButton = app.buttons["profile_settings_button"]
        let step3 = logger.reserveStep()
        if !profileButton.waitForExistence(timeout: 40) {
            logger.fail(step: step3, description: "Verify profile loaded", expected: "profile_settings_button visible", actual: "profile_settings_button missing")
            return
        }
        logger.success(step: step3, description: "Verify profile loaded")

        let step4 = logger.reserveStep()
        let latestAfter: String?
        do {
            latestAfter = try await factory.fetchLatestAuthUserID()
        } catch {
            logger.fail(step: step4, description: "bootstrap_profile_v1", expected: "admin users list fetch", actual: "\(error)")
            return
        }
        guard let latestAfter else {
            logger.fail(step: step4, description: "bootstrap_profile_v1", expected: "latest auth user id", actual: "nil from admin API")
            return
        }
        if latestAfter == latestBefore {
            logger.fail(step: step4, description: "bootstrap_profile_v1", expected: "new auth user created", actual: "latest auth user unchanged")
            return
        }
        let profileExists: Bool
        do {
            profileExists = try await factory.profileExists(userId: latestAfter)
        } catch {
            logger.fail(step: step4, description: "bootstrap_profile_v1", expected: "profiles lookup", actual: "\(error)")
            return
        }
        if !profileExists {
            logger.fail(step: step4, description: "bootstrap_profile_v1", expected: "profiles row exists", actual: "profiles row missing")
            return
        }
        logger.success(step: step4, description: "bootstrap_profile_v1")

        let step5 = logger.reserveStep()
        if app.buttons["auth_login_button"].exists {
            logger.fail(step: step5, description: "Verify no auth error shown", expected: "auth sheet dismissed", actual: "auth_login_button still visible")
            return
        }
        logger.success(step: step5, description: "Verify no auth error shown")
    }
}
