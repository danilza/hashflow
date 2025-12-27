import Foundation
import StoreKit
import SwiftUI
import Supabase

typealias AuthState = (event: AuthChangeEvent, session: Session?)

@MainActor
final class GameProfileViewModel: ObservableObject {

    enum AchievementTier {
        case achievement
        case mega
        case legend
    }

    @Published var profile: GameProfile
    @Published var bonusProduct: Product?
    @Published var adaptiveMessage: String?
    @Published var remoteProfile: SupabaseProfileRecord? {
        didSet {
            exclusivityMode = remoteProfile?.exclusivityMode ?? "open"
        }
    }
    @Published var exclusivityMode: String = "open"
    @Published var creditBalance: Int?
    @Published var movesBalance: Int?
    @Published var withdrawableBalance: Int?
    @Published var creditRefillNextAt: Date?
    @Published var isFreeRunActive: Bool = false
    var freeRunHoursRemaining: Int? {
        guard let until = profile.freeRunUntil else { return nil }
        let diff = until.timeIntervalSinceNow
        guard diff > 0 else { return 0 }
        return Int(ceil(diff / 3600))
    }
    var creditRefillCountdown: String? {
        guard let next = creditRefillNextAt else { return nil }
        let diff = next.timeIntervalSinceNow
        guard diff > 0 else { return "00:00" }
        let totalMinutes = Int(diff / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    @Published var myPendingSolutions: [UniquePipelineItem] = []
    @Published var myMintedSolutions: [UniquePipelineItem] = []
    @Published var otherPendingSolutions: [UniquePipelineItem] = []
    @Published var marketSolutions: [UniquePipelineItem] = []
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var levelUniqueSolutionCounts: [Int: Int] = [:]
    @Published var playerLevelStats: [Int: PlayerLevelStat] = [:]
    @Published var playerNFTs: [SolutionNFT] = []
    @Published var supabaseError: String?
    @Published var supabaseInfo: String?
    @Published var shouldPresentAuthSheet = false
    @Published var pendingOtpEmail: String?
    var pendingOtpPassword: String?
    @Published var pendingUsername: String?
    @Published var currentLevel: Level?
    @Published var currentLevelOrigin: LevelDifficulty?
    private var didFetchLevelCounts = false
    private var didFetchPlayerStats = false
    private var didFetchNFTs = false

    private var authListenerTask: Task<Void, Never>?
    private let dailyBonus = 50
    private let bonusProductID = "hashflow.bonus.500"
    private let minimumTopLevelId = 5
    private let starterUnlockedLevels = 5
    private var isRefreshingCredits = false
    private let initialUnlockedPerDifficulty = 1
    private let starterTopValue: Int
    init() {
        let firstLevelId = Level.all.first?.id ?? 1
        let starterTop = min(
            Level.all.last?.id ?? firstLevelId,
            firstLevelId + starterUnlockedLevels - 1
        )
        self.starterTopValue = starterTop
        profile = GameProfileViewModel.buildDefaultProfile(starterTop: starterTop)
        resetDailyMetaIfNeeded()

        shouldPresentAuthSheet = false
        supabaseInfo = nil
        Task {
            await loadProducts()
            await bootstrapSupabase()
        }
        authListenerTask = Task { [weak self] in
            guard let self else { return }

            for await state in SupabaseService.shared.client.auth.authStateChanges {
                await self.handleAuthState(state)
            }
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: [bonusProductID])
            bonusProduct = products.first
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func resetDailyBonusIfNeeded(currentDate: Date = Date()) {
        let calendar = Calendar.current
        if let lastDate = profile.lastBonusResetDate,
           calendar.isDate(lastDate, inSameDayAs: currentDate) {
            return
        }
        profile.lastBonusResetDate = currentDate
    }

    func resetDailyMetaIfNeeded(currentDate: Date = Date()) {
        resetDailyBonusIfNeeded(currentDate: currentDate)

        let calendar = Calendar.current
        if let last = profile.lastDailyDate,
           calendar.isDate(last, inSameDayAs: currentDate) {
            return
        }
        profile.lastDailyDate = currentDate
        profile.completedDailyDifficulties = []
    }

    func openLevel(_ level: Level, originDifficulty: LevelDifficulty? = nil) {
        currentLevel = level
        currentLevelOrigin = originDifficulty ?? level.difficulty
    }

    func closeLevel() {
        currentLevel = nil
    }

    func nextLevel(after level: Level) -> Level? {
        let difficulty = currentLevelOrigin ?? level.difficulty
        let levels = levelList(for: difficulty)
        guard let index = levels.firstIndex(where: { $0.id == level.id }) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < levels.count else { return nil }
        return levels[nextIndex]
    }

    func markDailyChallengeCompleted(difficulty: DailyDifficulty) {
        let key = difficulty.rawValue
        if !profile.completedDailyDifficulties.contains(key) {
            profile.completedDailyDifficulties.append(key)
            profile.lastDailyDate = Date()
        }
    }

    func isDailyDifficultyCompletedToday(_ difficulty: DailyDifficulty, currentDate: Date = Date()) -> Bool {
        let calendar = Calendar.current
        guard let last = profile.lastDailyDate,
              calendar.isDate(last, inSameDayAs: currentDate) else {
            return false
        }
        return profile.completedDailyDifficulties.contains(difficulty.rawValue)
    }

    func purchaseBonusPack() async {
        if bonusProduct == nil {
            await loadProducts()
        }
        guard let product = bonusProduct else { return }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified = verification {
                    profile.bonusPoints += 500
                    print("Credits pack purchased, now bonusPoints = \(profile.bonusPoints)")
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }

    @MainActor
    func refreshLevelUniqueSolutionCounts(force: Bool = false) async {
        if didFetchLevelCounts && !force { return }
        do {
            let counts = try await SupabaseService.shared.getLevelUniqueSolutionCounts()
            levelUniqueSolutionCounts = counts
            didFetchLevelCounts = true
        } catch {
            supabaseError = "Не удалось загрузить уникальные решения уровней."
        }
    }

    @MainActor
    func refreshPlayerLevelStats(force: Bool = false) async {
        if didFetchPlayerStats && !force { return }
        do {
            let user = try await SupabaseService.shared.currentUser()
            let stats = try await SupabaseService.shared.getPlayerLevelStats(playerId: user.id)
            var map: [Int: PlayerLevelStat] = [:]
            stats.forEach { map[$0.levelID] = $0 }
            playerLevelStats = map
            didFetchPlayerStats = true
        } catch SupabaseServiceError.notAuthenticated {
            // Игрок может быть оффлайн — просто не показываем ошибки.
        } catch {
            supabaseError = "Не удалось загрузить твои уникальные решения."
        }
    }

    @MainActor
    func refreshPlayerNFTs(force: Bool = false) async {
        if didFetchNFTs && !force { return }
        do {
            var nfts = try await SupabaseService.shared.getPlayerNFTs()
            if let wallet = remoteProfile?.walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
               !wallet.isEmpty {
                do {
                    let ownedItems = try await TonAssetService.shared.fetchOwnedNFTs(ownerAddress: wallet)
                    let ownedMap: [String: TonChainNFT] = Dictionary(uniqueKeysWithValues: ownedItems.compactMap { item in
                        guard let normalized = TonAssetService.normalizeAddress(item.address) else { return nil }
                        return (normalized, item)
                    })
                    nfts = nfts.map { nft in
                        guard let address = nft.nftAddress,
                              let normalized = TonAssetService.normalizeAddress(address) else {
                            return nft.withChainOverlay(ownerAddress: nil, metadataName: nil, metadataImage: nil, ownedByCurrentPlayer: nil)
                        }
                        if let chainEntry = ownedMap[normalized] {
                            let image = chainEntry.metadata?.image ?? chainEntry.metadata?.contentUrl
                            return nft.withChainOverlay(
                                ownerAddress: chainEntry.owner?.address,
                                metadataName: chainEntry.metadata?.name,
                                metadataImage: image,
                                ownedByCurrentPlayer: true
                            )
                        } else {
                            return nft.withChainOverlay(
                                ownerAddress: nil,
                                metadataName: nil,
                                metadataImage: nil,
                                ownedByCurrentPlayer: false
                            )
                        }
                    }
                } catch {
                    print("Failed to resolve TON ownership:", error)
                }
            }
            playerNFTs = nfts
            didFetchNFTs = true
        } catch SupabaseServiceError.notAuthenticated {
            // допустимо для анонимных игроков
        } catch {
            print("Failed to fetch NFTs:", error)
        }
    }

    @MainActor
    func refreshCreditsAndSolutions() async {
        if isRefreshingCredits { return }
        isRefreshingCredits = true
        defer { isRefreshingCredits = false }
        do {
            let economy = try await SupabaseService.shared.fetchPlayerEconomy()
            creditBalance = economy.creditBalance
            movesBalance = economy.dailyMovesLeft
            withdrawableBalance = nil
            if let status = try? await SupabaseService.shared.fetchCreditRefillStatus() {
                creditRefillNextAt = status.nextRefillAt
            }
            if let hours = try? await SupabaseService.shared.fetchFreeRunRemainingHours() {
                if hours > 0 {
                    profile.freeRunUntil = Date().addingTimeInterval(Double(hours) * 3600)
                } else {
                    profile.freeRunUntil = nil
                }
            }
            isFreeRunActive = (try? await SupabaseService.shared.isFreeRunActive()) ?? false
            if let until = profile.freeRunUntil, until > Date() {
                isFreeRunActive = true
            }
            myPendingSolutions = try await SupabaseService.shared.fetchMyUniqueSolutions()
            myMintedSolutions = try await SupabaseService.shared.fetchMyMintedSolutions()
            otherPendingSolutions = try await SupabaseService.shared.fetchOtherMintableSolutions()
            marketSolutions = try await SupabaseService.shared.fetchMarketSolutions()
            supabaseError = nil
        } catch SupabaseServiceError.notAuthenticated {
            supabaseError = "Войдите, чтобы увидеть решения."
        } catch {
            if let urlErr = error as? URLError, urlErr.code == .cancelled {
                // Игнорируем отмененные запросы, чтобы не перезаписывать состояние.
                return
            }
            supabaseError = "Не удалось загрузить список решений: \(error.localizedDescription)"
            print("refreshCreditsAndSolutions error:", error)
        }
    }

    func mintMySolution(_ item: UniquePipelineItem, cost: Int? = nil) async {
        guard remoteProfile != nil else { return }
        await MainActor.run {
            supabaseInfo = nil
            supabaseError = "Минт запускается только через edge."
        }
    }

    func purchaseSolution(_ item: UniquePipelineItem, price: Int) async {
        guard remoteProfile != nil else { return }
        do {
            try await SupabaseService.shared.purchaseSolution(pipelineHash: item.pipelineHash, price: price)
            await MainActor.run {
                self.supabaseInfo = "Покупка успешна, free-run обновится после синхронизации."
                self.supabaseError = nil
            }
            await refreshCreditsAndSolutions()
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
        }
    }

    func updateSolutionPrice(_ item: UniquePipelineItem, price: Int?, forSale: Bool) async {
        guard remoteProfile != nil else { return }
        do {
            _ = try await SupabaseService.shared.setSolutionPrice(pipelineHash: item.pipelineHash, price: price, forSale: forSale)
            await refreshCreditsAndSolutions()
            await MainActor.run {
                self.supabaseInfo = "Цена обновлена."
                self.supabaseError = nil
            }
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
        }
    }

    func chargeRunAttempt(levelId: Int, nodes: Int, pipelineHash: String, lastPipelineHash: String?, levelTier: String) async -> Bool {
        guard remoteProfile != nil else {
            await MainActor.run {
                self.supabaseError = "Войдите, чтобы запускать попытки."
            }
            return false
        }
        do {
            let cost = try await SupabaseService.shared.calculateRunCost(
                levelId: levelId,
                nodes: nodes,
                pipelineHash: pipelineHash,
                lastPipelineHash: lastPipelineHash,
                levelTier: levelTier
            )
            let result = try await SupabaseService.shared.consumeRunResources(cost: cost)
            await MainActor.run {
                self.movesBalance = result.remainingMoves
                self.creditBalance = result.remainingCredits
                self.supabaseError = result.success ? nil : "Ходы закончились."
            }
            return result.success
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
            return false
        }
    }

    func consumeCredits(amount: Int, source: String) async -> Bool {
        guard remoteProfile != nil else {
            await MainActor.run {
                self.supabaseError = "Войдите, чтобы тратить кредиты."
            }
            return false
        }
        do {
            let result = try await SupabaseService.shared.consumeRunResources(cost: amount)
            await MainActor.run {
                self.movesBalance = result.remainingMoves
                self.creditBalance = result.remainingCredits
                self.supabaseError = result.success ? nil : "Недостаточно ресурсов."
            }
            return result.success
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
            return false
        }
    }

    func addRespect(_ amount: Int) {
        profile.totalRespect = max(0, profile.totalRespect + amount)
    }

    func recordAttempt(for level: Level, thinkingUnits: Int, resultValue: UInt32, success: Bool) {
        var progress = profile.levelProgress[level.id, default: LevelProgress()]
        progress.totalAttempts += 1
        progress.totalThinkingUnits += max(1, thinkingUnits)
        if success {
            progress.totalCompletions += 1
        }
        progress.maxValueAchieved = max(progress.maxValueAchieved, resultValue)
        profile.levelProgress[level.id] = progress
    }

    func markLevelCompleted(_ level: Level, isUnique: Bool) -> (bonus: Int, breakdown: [String]) {
        guard isUnique else { return (0, []) }
        profile.completedLevelIds.insert(level.id)
        addRespect(5)
        addHistoryEntry(for: level, entry: "Уникальное решение уровня → +5 респекта")
        registerProgress(for: level)
        return (5, ["Уникальное решение → +5"])
    }

    private func registerProgress(for level: Level) {
        let today = Date()
        let unlockedNext = min(level.id + 1, Level.all.last?.id ?? level.id)
        profile.highestUnlockedLevelId = max(profile.highestUnlockedLevelId, unlockedNext)
        profile.currentTopLevelId = max(profile.currentTopLevelId, unlockedNext)
        profile.lastProgressDate = today
        adaptiveMessage = nil
        queueCloudProgressUpload()
    }

    func addHistoryEntry(for level: Level, entry: String) {
        profile.levelHistory[level.id, default: []].append(entry)
    }

    func history(for level: Level) -> [String] {
        profile.levelHistory[level.id] ?? []
    }

    func isLevelCompleted(_ level: Level) -> Bool {
        profile.completedLevelIds.contains(level.id)
    }

    func canPlay(level: Level) -> Bool {
        let baseId = Level.all.first?.id ?? 1
        let starterMax = min(baseId + starterUnlockedLevels - 1, Level.all.last?.id ?? baseId)
        if level.id <= starterMax {
            return true
        }
        if isInitialLevel(in: level.difficulty, level: level) {
            return true
        }
        guard level.id <= profile.currentTopLevelId else { return false }
        let ordered = Level.all.sorted { $0.id < $1.id }
        guard let index = ordered.firstIndex(where: { $0.id == level.id }) else { return true }
        if index == 0 { return true }
        let previous = ordered[index - 1]
        return isLevelCompleted(previous)
    }

    func adjustLevelRangeIfNeeded(currentDate: Date = Date()) {
        guard let lastProgress = profile.lastProgressDate else { return }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastProgress, to: currentDate).day ?? 0
        let minLevel = max(minimumTopLevelId, Level.all.first?.id ?? 1)
        if days >= 2 && profile.currentTopLevelId > minLevel {
            profile.currentTopLevelId = max(minLevel, profile.currentTopLevelId - 1)
            adaptiveMessage = "Алгоритм заметил, что ты застрял на текущей высоте. Мы сузили зону уровней, чтобы было проще разогнаться. Поднимешься снова — зона расширится."
        }
    }

    func hasTriedSolution(level: Level, hash: String) -> Bool {
        profile.triedSolutionHashes[level.id]?.contains(hash) ?? false
    }

    func signIn(email: String, password: String, preferredUsername: String? = nil) async {
        do {
            let profile = try await SupabaseService.shared.signIn(email: email, password: password, preferredUsername: preferredUsername)
            await MainActor.run {
                self.remoteProfile = profile
                self.supabaseError = nil
                self.supabaseInfo = nil
                self.shouldPresentAuthSheet = false
            }
            if let desired = preferredUsername?.trimmingCharacters(in: .whitespacesAndNewlines),
               !desired.isEmpty,
               profile.username.compare(desired, options: .caseInsensitive) != .orderedSame {
                do {
                    let updated = try await SupabaseService.shared.updateUsername(to: desired)
                    await MainActor.run {
                        self.remoteProfile = updated
                    }
                } catch {
                    print("Failed to align username:", error)
                }
            }
            await refreshLeaderboard()
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
                self.supabaseInfo = nil
            }
        }
    }

    func signUp(email: String, password: String, username: String) async {
        do {
            let payload = [
                "email": email,
                "password": password,
                "username": username
            ]
            print("SIGNUP PAYLOAD:", payload)
            if let json = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
               let jsonString = String(data: json, encoding: .utf8) {
                print("SIGNUP JSON:\n\(jsonString)")
            }
            try await SupabaseService.shared.signUp(email: email, password: password, username: username)
            self.pendingOtpEmail = email
            self.pendingOtpPassword = password
            self.pendingUsername = username
            self.supabaseError = nil
            self.supabaseInfo = "Мы отправили код на \(email). Введи его, чтобы продолжить."
            self.remoteProfile = nil
            self.shouldPresentAuthSheet = true
            Task {
                await SupabaseService.shared.debugOtpRows(for: email)
            }
        } catch {
            let localized = error.localizedDescription
            let serviceMessage: String
            if localized.contains("User already registered") {
                serviceMessage = "Почта уже зарегистрирована. Войдите."
            } else {
                serviceMessage = "Ошибка сервиса: \(localized)"
            }
            await MainActor.run {
                self.supabaseError = serviceMessage
                self.supabaseInfo = nil
            }
        }
    }

    func continueAnonymously() {
        supabaseError = nil
        supabaseInfo = nil
        Task {
            do {
                let profile = try await SupabaseService.shared.signInAnonymously()
                await MainActor.run {
                    self.remoteProfile = profile
                    self.shouldPresentAuthSheet = false
                }
                await syncProgressAfterLogin()
                await refreshLeaderboard()
            } catch {
                await MainActor.run {
                    self.supabaseError = AuthErrorMapper.message(for: error)
                    self.shouldPresentAuthSheet = true
                }
            }
        }
    }

    func signInWithGoogle() async {
        await MainActor.run {
            self.cancelOtpFlow()
            self.supabaseError = nil
            self.supabaseInfo = "Заверши вход через браузер…"
        }
        do {
            try await SupabaseService.shared.signInWithGoogle()
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
                self.supabaseInfo = nil
            }
        }
    }

    func updateUsername(to newUsername: String) async throws {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = try await SupabaseService.shared.updateUsername(to: trimmed)
        remoteProfile = profile
    }

    func updateWalletAddress(to newAddress: String?) async throws {
        let trimmed = newAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = try await SupabaseService.shared.updateWalletAddress(to: trimmed)
        remoteProfile = profile
        didFetchNFTs = false
        await refreshPlayerNFTs(force: true)
    }

    func updateExclusivityMode(to newMode: String) async {
        guard remoteProfile != nil else { return }
        do {
            let updated = try await SupabaseService.shared.setExclusivityMode(to: newMode)
            await MainActor.run {
                self.remoteProfile = updated
                self.supabaseInfo = "Настройка эксклюзивности обновлена."
                self.supabaseError = nil
            }
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
        }
    }

    func signOut() async throws {
        try await SupabaseService.shared.client.auth.signOut()
        remoteProfile = nil
        shouldPresentAuthSheet = true
        playerNFTs = []
        didFetchNFTs = false
        cancelOtpFlow()
    }

    func purchaseSkin(id: String) {
        if profile.ownedSkins.contains(id) {
            applySkin(id: id)
            return
        }
        profile.ownedSkins.insert(id)
        applySkin(id: id)
    }

    func applySkin(id: String) {
        guard profile.ownedSkins.contains(id) else { return }
        profile.activeSkin = id
    }

    func confirmEmailOtp(code: String) async {
        guard let email = pendingOtpEmail else { return }
        guard let password = pendingOtpPassword else {
            await MainActor.run {
                self.supabaseError = "Не удалось подтвердить пароль. Попробуй ещё раз."
            }
            return
        }
        do {
            let profile = try await SupabaseService.shared.verifyEmailOtp(
                email: email,
                otp: code,
                password: password,
                preferredUsername: pendingUsername
            )
            await MainActor.run {
                self.remoteProfile = profile
                self.supabaseInfo = "Код подтверждён. Добро пожаловать!"
                self.supabaseError = nil
                self.pendingOtpEmail = nil
                self.pendingOtpPassword = nil
                self.pendingUsername = nil
                self.shouldPresentAuthSheet = false
            }
            await refreshLeaderboard()
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
        }
    }

    func cancelOtpFlow() {
        pendingOtpEmail = nil
        pendingOtpPassword = nil
        pendingUsername = nil
        supabaseInfo = nil
        supabaseError = nil
            
    }

    func deleteAccount() async {
        do {
            try await SupabaseService.shared.deleteAccountData()
            await MainActor.run {
                self.resetLocalProfile()
                self.shouldPresentAuthSheet = true
                self.supabaseInfo = "Аккаунт удалён."
            }
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
            }
        }
    }

    @MainActor
    func refreshLeaderboard(limit: Int = 20) async {
        do {
            let entries = try await SupabaseService.shared.fetchLeaderboardByUniqueSolutions(limit: limit)
            leaderboardEntries = entries
            supabaseError = nil
            print("Leaderboard entries count:", entries.count)
            print(entries)
        } catch {
            supabaseError = error.localizedDescription
        }
    }

    func recordSolution(level: Level, hash: String) {
        if profile.triedSolutionHashes[level.id] == nil {
            profile.triedSolutionHashes[level.id] = []
        }
        profile.triedSolutionHashes[level.id]?.insert(hash)
    }

    func solutionCount(for level: Level) -> Int {
        profile.triedSolutionHashes[level.id]?.count ?? 0
    }

    func progress(for level: Level) -> LevelProgress {
        profile.levelProgress[level.id] ?? LevelProgress()
    }

    func achievementTier(for level: Level) -> AchievementTier? {
        let count = solutionCount(for: level)
        if count >= 100 { return .legend }
        if count >= 10 { return .mega }
        if count >= 3 { return .achievement }
        return nil
    }

    func tierLabel(for tier: AchievementTier?) -> String? {
        switch tier {
        case .achievement: return "Ачивка"
        case .mega: return "Мегаочивка"
        case .legend: return "Легенда"
        case .none: return nil
        }
    }

    func tierGradient(for tier: AchievementTier?) -> LinearGradient? {
        switch tier {
        case .achievement:
            return LinearGradient(colors: [
                Color(red: 0.25, green: 0.28, blue: 0.30),
                Color(red: 0.12, green: 0.13, blue: 0.15)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mega:
            return LinearGradient(colors: [
                Color(red: 0.40, green: 0.24, blue: 0.05),
                Color(red: 0.20, green: 0.12, blue: 0.03)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legend:
            return LinearGradient(colors: [
                Color(red: 0.32, green: 0.18, blue: 0.09),
                Color(red: 0.15, green: 0.08, blue: 0.04)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .none:
            return nil
        }
    }

    private func respectBreakdown(for level: Level, attempts: Int, resultValue: UInt32) -> (Int, [String]) {
        return (0, [])
    }

    @MainActor
    private func syncProgressAfterLogin() async {
        guard remoteProfile != nil else { return }
        do {
            if let snapshot = try await SupabaseService.shared.fetchPlayerProgress() {
                applyCloudProgress(snapshot)
            } else {
                let completed = Array(profile.completedLevelIds)
                let highest = max(profile.currentTopLevelId, starterTopValue)
                try await SupabaseService.shared.upsertPlayerProgressSnapshot(
                    completedLevelIDs: completed,
                    highestUnlockedLevelID: highest
                )
            }
        } catch SupabaseServiceError.notAuthenticated {
            // пользователь ещё не авторизован — пропускаем.
        } catch {
            print("Failed to sync progress:", error)
        }
    }

    @MainActor
    private func applyCloudProgress(_ snapshot: PlayerProgressSnapshot) {
        let highest = max(snapshot.highestUnlockedLevelID, starterTopValue)
        profile.completedLevelIds = Set(snapshot.completedLevelIDs)
        profile.highestUnlockedLevelId = highest
        profile.currentTopLevelId = highest
        profile.lastProgressDate = snapshot.updatedAt ?? Date()
    }

    private func queueCloudProgressUpload() {
        guard remoteProfile != nil else { return }
        let completed = Array(profile.completedLevelIds)
        let highest = max(profile.currentTopLevelId, starterTopValue)
        Task {
            do {
                try await SupabaseService.shared.upsertPlayerProgressSnapshot(
                    completedLevelIDs: completed,
                    highestUnlockedLevelID: highest
                )
            } catch {
                print("Failed to upload progress:", error)
            }
        }
    }

    private func bootstrapSupabase() async {
        do {
            if ProcessInfo.processInfo.environment["UITEST_MODE"] == "1",
               ProcessInfo.processInfo.environment["UITEST_FORCE_SIGNOUT"] == "1" {
                try? await SupabaseService.shared.client.auth.signOut()
                await MainActor.run {
                    self.remoteProfile = nil
                    self.supabaseError = nil
                    self.supabaseInfo = nil
                    self.shouldPresentAuthSheet = true
                }
                return
            }
            if ProcessInfo.processInfo.environment["UITEST_MODE"] == "1",
               let email = ProcessInfo.processInfo.environment["UITEST_EMAIL"],
               let password = ProcessInfo.processInfo.environment["UITEST_PASSWORD"] {
                try? await SupabaseService.shared.client.auth.signOut()
                let profile = try await SupabaseService.shared.signIn(
                    email: email,
                    password: password,
                    requiresEmailVerification: false
                )
                await MainActor.run {
                    self.remoteProfile = profile
                    self.supabaseError = nil
                    self.supabaseInfo = nil
                    self.shouldPresentAuthSheet = false
                }
                await syncProgressAfterLogin()
                await refreshPlayerNFTs(force: true)
                await refreshCreditsAndSolutions()
            } else if let profile = try await SupabaseService.shared.bootstrapCurrentProfile() {
                await MainActor.run {
                    self.remoteProfile = profile
                    self.supabaseError = nil
                    self.supabaseInfo = nil
                    self.shouldPresentAuthSheet = false
                }
                await syncProgressAfterLogin()
                await refreshPlayerNFTs(force: true)
                await refreshCreditsAndSolutions()
            } else {
                await MainActor.run {
                    self.shouldPresentAuthSheet = true
                }
            }
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
                self.supabaseInfo = nil
                self.shouldPresentAuthSheet = true
            }
        }
        await refreshLeaderboard()
        await refreshPlayerNFTs()
    }

    private func isInitialLevel(in difficulty: LevelDifficulty, level: Level) -> Bool {
        let levels = levelList(for: difficulty)
        guard let first = levels.first else { return false }
        return level.id == first.id
    }

    private func levelList(for difficulty: LevelDifficulty) -> [Level] {
        Level.all.filter { $0.difficulty == difficulty }.sorted { $0.id < $1.id }
    }

    private func handleAuthState(_ state: AuthState) async {
        print(
            "AuthState event =",
            state.event.rawValue,
            "session is nil:",
            state.session == nil
        )
        if state.session == nil && state.event == .signedIn {
            print("SignedIn event without session, ignoring.")
            return
        }
        switch state.event {
        case .initialSession, .signedIn:
            if let session = state.session {
                do {
            let profile = try await SupabaseService.shared.profile(from: session)
            await MainActor.run {
                self.remoteProfile = profile
                self.supabaseError = nil
                self.supabaseInfo = nil
                self.shouldPresentAuthSheet = false
            }
            await syncProgressAfterLogin()
            await refreshLeaderboard()
            await refreshPlayerNFTs(force: true)
            await refreshCreditsAndSolutions()
        } catch {
            await MainActor.run {
                self.supabaseError = AuthErrorMapper.message(for: error)
                self.supabaseInfo = nil
            }
                }
            }
        case .signedOut:
            await MainActor.run {
                self.remoteProfile = nil
                self.supabaseError = nil
                self.supabaseInfo = nil
                self.shouldPresentAuthSheet = true
                self.playerNFTs = []
                self.didFetchNFTs = false
                self.creditBalance = nil
                self.movesBalance = nil
                self.withdrawableBalance = nil
            }
        default:
            break
        }
    }
}

private extension GameProfileViewModel {
    static func buildDefaultProfile(starterTop: Int) -> GameProfile {
        GameProfile(
            totalRespect: 0,
            completedLevelIds: [],
            levelHistory: [:],
            bonusPoints: 0,
            lastBonusResetDate: nil,
            hardcoreMode: false,
            triedSolutionHashes: [:],
            highestUnlockedLevelId: starterTop,
            currentTopLevelId: starterTop,
            lastProgressDate: nil,
            lastDailyDate: nil,
            completedDailyDifficulties: [],
            levelProgress: [:],
            ownedSkins: [],
            activeSkin: nil,
            freeRunUntil: nil
        )
    }

    func resetLocalProfile() {
        profile = GameProfileViewModel.buildDefaultProfile(starterTop: starterTopValue)
        leaderboardEntries = []
        playerNFTs = []
        pendingOtpEmail = nil
        pendingOtpPassword = nil
        remoteProfile = nil
        supabaseError = nil
        supabaseInfo = nil
        didFetchNFTs = false
    }
}
