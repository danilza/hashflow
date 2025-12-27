import Foundation

struct LevelProgress: Codable {
    var totalAttempts: Int = 0
    var totalCompletions: Int = 0
    var totalThinkingUnits: Int = 0
    var maxValueAchieved: UInt32 = 0
}

struct GameProfile: Codable {
    var totalRespect: Int
    var completedLevelIds: Set<Int>
    var levelHistory: [Int: [String]]

    var bonusPoints: Int
    var lastBonusResetDate: Date?
    var hardcoreMode: Bool
    var triedSolutionHashes: [Int: Set<String>]

    var highestUnlockedLevelId: Int
    var currentTopLevelId: Int
    var lastProgressDate: Date?

    var lastDailyDate: Date?
    var completedDailyDifficulties: [String]
    var levelProgress: [Int: LevelProgress]
    var ownedSkins: Set<String> = []
    var activeSkin: String?
    var freeRunUntil: Date?
}

enum PlayerRank: String, CaseIterable {
    case newbie = "Новичок"
    case bitTinkerer = "Битовый экспериментатор"
    case gpuMind = "GPU-мозг"
    case asicBrain = "ASIC-сознание"
    case shaMaster = "Мастер SHA-256"
}

extension GameProfile {
    var rank: PlayerRank {
        switch totalRespect {
        case ..<100: return .newbie
        case 100..<300: return .bitTinkerer
        case 300..<800: return .gpuMind
        case 800..<1500: return .asicBrain
        default: return .shaMaster
        }
    }
}
