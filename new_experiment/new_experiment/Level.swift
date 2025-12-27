import Foundation

struct Level: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let description: String
    let inputValue: UInt32
    let targetValue: UInt32
    let rewardRespect: Int
    let solutionsCount: Int
    let conveyorLength: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, description, inputValue, targetValue, rewardRespect, solutionsCount, conveyorLength
    }

    init(
        id: Int,
        name: String,
        description: String,
        inputValue: UInt32,
        targetValue: UInt32,
        rewardRespect: Int,
        solutionsCount: Int,
        conveyorLength: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.inputValue = inputValue
        self.targetValue = targetValue
        self.rewardRespect = rewardRespect
        self.solutionsCount = solutionsCount
        self.conveyorLength = conveyorLength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputValue = try container.decode(UInt32.self, forKey: .inputValue)
        targetValue = try container.decode(UInt32.self, forKey: .targetValue)
        rewardRespect = try container.decode(Int.self, forKey: .rewardRespect)
        solutionsCount = try container.decode(Int.self, forKey: .solutionsCount)
        conveyorLength = try container.decodeIfPresent(Int.self, forKey: .conveyorLength) ?? Level.defaultConveyorLength(for: id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(inputValue, forKey: .inputValue)
        try container.encode(targetValue, forKey: .targetValue)
        try container.encode(rewardRespect, forKey: .rewardRespect)
        try container.encode(solutionsCount, forKey: .solutionsCount)
        try container.encode(conveyorLength, forKey: .conveyorLength)
    }

    var difficulty: LevelDifficulty {
        let offset = id - 1
        if offset < LevelGenerator.easyCount {
            return .easy
        } else if offset < LevelGenerator.easyCount + LevelGenerator.mediumCount {
            return .medium
        } else {
            return .asic
        }
    }

    var legendHint: String? {
        switch id {
        case 13:
            return "Нечётные биты шепчут о первом побеге. XOR здесь — не операция, а окно."
        case 42:
            return "Ответ на всё — это не число, а комбинация. Введи маску, которая превращает 42 в твою свободу."
        case 256:
            return "Сдвиг на восемь — как вдохнуть вакуум. Если почувствуешь холод, ты близко к разгадке."
        default:
            return nil
        }
    }
}

extension Level {
    static let all: [Level] = LevelGenerator.generateLevels()

    static func defaultConveyorLength(for id: Int) -> Int {
        switch id {
        case 1...100:
            return 6
        case 101...300:
            return 8
        default:
            return 10
        }
    }

    static func level(withID id: Int) -> Level? {
        all.first(where: { $0.id == id })
    }
}

enum LevelGenerator {
    static let easyCount = 13
    static let mediumCount = 300

    static func generateLevels() -> [Level] {
        (1...1000).map { generateLevel(id: $0) }
    }

    private static func generateLevel(id: Int) -> Level {
        let info = tier(for: id)
        let base = UInt32((id * 37) % 10_000) + 10
        let mask = UInt32(((id * 91) % 255) + 1)
        let shiftSpan = max(1, info.shiftRange.upperBound - info.shiftRange.lowerBound + 1)
        let shiftValue = info.shiftRange.lowerBound + (id % shiftSpan)
        let shift = UInt32(min(31, shiftValue))
        let target = ((base << shift) ^ mask) & 0xFFFF_FFFF

        return Level(
            id: id,
            name: name(for: id),
            description: description(for: id, tier: info, mask: mask, shift: shift),
            inputValue: base,
            targetValue: target,
            rewardRespect: info.baseReward + (id % info.rewardSpread),
            solutionsCount: 0,
            conveyorLength: Level.defaultConveyorLength(for: id)
        )
    }

    private struct TierInfo {
        let shiftRange: ClosedRange<Int>
        let baseReward: Int
        let rewardSpread: Int
        let descriptionHint: String
    }

    private static func tier(for id: Int) -> TierInfo {
        switch id {
        case 1...100:
            return TierInfo(shiftRange: 1...4, baseReward: 40, rewardSpread: 20, descriptionHint: "Учимся комбинировать XOR и Shift.")
        case 101...300:
            return TierInfo(shiftRange: 1...5, baseReward: 80, rewardSpread: 30, descriptionHint: "Мало узлов, больше точности.")
        case 301...600:
            return TierInfo(shiftRange: 2...6, baseReward: 130, rewardSpread: 40, descriptionHint: "Работа с масками и сдвигами.")
        case 601...900:
            return TierInfo(shiftRange: 3...6, baseReward: 180, rewardSpread: 50, descriptionHint: "Минимум блоков, максимум контроля.")
        default:
            return TierInfo(shiftRange: 4...7, baseReward: 250, rewardSpread: 80, descriptionHint: "Только для тех, кто мыслит как ASIC.")
        }
    }

    private static func name(for id: Int) -> String {
        switch id {
        case 901...1000:
            let titles = ["ASIC Trial", "Сон видеокарты", "Мышление Сатоши", "Hash Oracle", "Quantum Shift"]
            return titles[id % titles.count] + " #\(id)"
        case 601...900:
            return "Хард #\(id)"
        case 301...600:
            return "Puzzle #\(id)"
        case (easyCount + 1)...(easyCount + mediumCount):
            let stage = id - easyCount
            let titles = ["Warp Boost", "Shader Pulse", "Tensor Flux", "Memory Sweep", "Voltage Drift", "Pipeline Surge"]
            let label = titles[(stage - 1) % titles.count]
            return "\(label) · Stage \(stage)"
        default:
            return "Базовый уровень #\(id)"
        }
    }

    private static func description(for id: Int, tier: TierInfo, mask: UInt32, shift: UInt32) -> String {
        if (610...619).contains(id) {
            return "Серия 610: разные входы, общая цель. Маска \(mask), shift \(shift)."
        }
        return tier.descriptionHint
    }

}

enum LevelDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case asic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Обучающие"
        case .medium: return "Средние"
        case .asic: return "ASIC-мозг"
        }
    }
}

enum DailyDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy = "Лёгкое"
    case normal = "Нормальное"
    case hard = "Хардкор"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Лёгкое"
        case .normal: return "Нормальное"
        case .hard: return "Хардкор"
        }
    }

    var description: String {
        switch self {
        case .easy:
            return "Разогреть мозг и вспомнить, что такое XOR и сдвиг."
        case .normal:
            return "Уже нужно думать, а не просто тыкать."
        case .hard:
            return "Режим: «я решил сам влезть в голову видеокарте»."
        }
    }
}

struct DailyChallengeGenerator {
    static func levels(for date: Date, difficulty: DailyDifficulty) -> [Level] {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let baseSeed = dayOfYear + difficultySeedOffset(difficulty)

        var result: [Level] = []

        for index in 0..<3 {
            let id = 10_000 + difficultyIdOffset(difficulty) + index
            let seed = baseSeed + index * 17

            let input: UInt32
            let target: UInt32
            let rewardRespect: Int

            switch difficulty {
            case .easy:
                input = UInt32((seed * 37) % 200 + 10)
                let shift = seed % 3 + 1
                target = (input << shift) & 0xFFFF_FFFF
                rewardRespect = 20

            case .normal:
                input = UInt32((seed * 73) % 5_000 + 100)
                let mask = UInt32((seed * 19) % 255 + 1)
                let shift = seed % 4 + 1
                let mid = (input ^ mask) & 0xFFFF_FFFF
                target = (mid << shift) & 0xFFFF_FFFF
                rewardRespect = 40

            case .hard:
                input = UInt32((seed * 113) % 50_000 + 1_000)
                let mask1 = UInt32((seed * 31) % 0xFFFF)
                let mask2 = UInt32((seed * 47) % 0xFFFF_FFFF)
                let shift1 = seed % 5 + 1
                let shift2 = (seed / 3) % 5 + 1
                let step1 = (input ^ mask1) & 0xFFFF_FFFF
                let step2 = (step1 << shift1) & 0xFFFF_FFFF
                let step3 = (step2 ^ mask2) & 0xFFFF_FFFF
                target = (step3 << shift2) & 0xFFFF_FFFF
                rewardRespect = 100
            }

            let level = Level(
                id: id,
                name: "День \(dayOfYear): \(difficulty.displayName) \(index + 1)/3",
                description: descriptionFor(index: index, difficulty: difficulty),
                inputValue: input,
                targetValue: target,
                rewardRespect: rewardRespect,
                solutionsCount: 0,
                conveyorLength: Level.defaultConveyorLength(for: id)
            )

            result.append(level)
        }

        return result
    }

    private static func difficultySeedOffset(_ difficulty: DailyDifficulty) -> Int {
        switch difficulty {
        case .easy: return 0
        case .normal: return 1_000
        case .hard: return 2_000
        }
    }

    private static func difficultyIdOffset(_ difficulty: DailyDifficulty) -> Int {
        switch difficulty {
        case .easy: return 0
        case .normal: return 100
        case .hard: return 200
        }
    }

    private static func descriptionFor(index: Int, difficulty: DailyDifficulty) -> String {
        switch (difficulty, index) {
        case (.easy, 0):
            return "Разогрев: попробуй получить целевое число за несколько простых шагов."
        case (.easy, 1):
            return "Чуть сложнее: играйся с маской и сдвигом."
        case (.easy, 2):
            return "Финальный лёгкий: закрепи механику."

        case (.normal, 0):
            return "Старт нормального режима: числа крупнее, думать придётся внимательнее."
        case (.normal, 1):
            return "Комбинация XOR + ShiftLeft. Следи за Trace."
        case (.normal, 2):
            return "Малый лимит узлов: оптимизируй цепочку."

        case (.hard, 0):
            return "Разведка боем: большие числа, ограниченные узлы."
        case (.hard, 1):
            return "Почувствуй, как думает видеокарта на полпути к SHA-256."
        case (.hard, 2):
            return "Хардкор: бездумный перебор тут не поможет."
        default:
            return "Ежедневное испытание: собери цепочку и попади в цель."
        }
    }
}
