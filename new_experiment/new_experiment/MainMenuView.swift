import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel

    var body: some View {
        HackerMainMenuView()
            .environmentObject(profileVM)
            .sheet(isPresented: $profileVM.shouldPresentAuthSheet) {
                SupabaseAuthSheetView(viewModel: profileVM)
            }
            .fullScreenCover(isPresented: currentLevelPresentedBinding) {
                if let levelBinding = levelBinding {
                    NavigationView {
                        LevelPlayView(level: levelBinding, originDifficulty: profileVM.currentLevelOrigin)
                            .environmentObject(profileVM)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                } else {
                    EmptyView()
                }
            }
    }

    private var currentLevelPresentedBinding: Binding<Bool> {
        Binding(
            get: { profileVM.currentLevel != nil },
            set: { presenting in
                if !presenting {
                    profileVM.closeLevel()
                }
            }
        )
    }

    private var levelBinding: Binding<Level>? {
        guard let currentLevel = profileVM.currentLevel else { return nil }
        return Binding(
            get: { profileVM.currentLevel ?? currentLevel },
            set: { newValue in
                profileVM.currentLevel = newValue
            }
        )
    }
}

struct LevelListView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                ForEach(LevelDifficulty.allCases) { difficulty in
                    NavigationLink {
                        LevelDifficultyListView(difficulty: difficulty)
                            .environmentObject(profileVM)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                                Text(difficulty.displayName.uppercased())
                                    .terminalText(18, weight: .semibold)
                                Text(description(for: difficulty))
                                    .terminalText(14)
                                    .foregroundColor(HFTheme.Colors.accentDim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(HFTheme.Colors.accentSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .terminalCard()
                    }
                    .accessibilityIdentifier("difficulty_\(difficulty.id)")
                    .buttonStyle(.plain)
                }
            }
            .padding(HFTheme.Spacing.l)
        }
        .accessibilityIdentifier("level_list_view")
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .applyToolbarBackground()
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("УРОВНИ")
                    .terminalText(18, weight: .semibold)
            }
        }
    }

    private func description(for difficulty: LevelDifficulty) -> String {
        switch difficulty {
        case .easy: return "Разогрев для новичков — доступно сразу."
        case .medium: return "Следующий уровень задач — открывается по порядку."
        case .asic: return "Для тех, кто мыслит как ASIC: последовательные испытания."
        }
    }
}

struct LevelDifficultyListView: View, Identifiable {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss
    let difficulty: LevelDifficulty
    var id: String { difficulty.id }
    @State private var showRequirements = false
    private var levels: [Level] {
        Level.all.filter { $0.difficulty == difficulty }
    }

    var body: some View {
        levelListContent
    }

    private var levelListContent: some View {
        ScrollView {
            LazyVStack(spacing: HFTheme.Spacing.m) {
                ForEach(levels) { level in
                    levelRow(for: level)
                }
            }
        }
        .padding(HFTheme.Spacing.l)
        .accessibilityIdentifier("level_difficulty_list_view")
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationTitle(difficulty.displayName)
        .navigationBarBackButtonHidden(true)
        .applyToolbarBackground()
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ToolbarNavButton(title: "Что нужно сделать", systemName: "questionmark.circle") {
                    showRequirements = true
                }
            }
        }
        .sheet(isPresented: $showRequirements) {
            RequirementsSheet(
                title: difficulty.displayName,
                description: requirementText(for: difficulty, hardcore: profileVM.profile.hardcoreMode)
            )
        }
        .task {
            await profileVM.refreshLevelUniqueSolutionCounts()
            await profileVM.refreshPlayerLevelStats()
        }
    }

    private func levelRow(for level: Level) -> some View {
        let canPlay = profileVM.canPlay(level: level)
        return Button {
            guard canPlay else { return }
            profileVM.openLevel(level, originDifficulty: difficulty)
        } label: {
            levelRowContent(level: level, canPlay: canPlay)
                .opacity(canPlay ? 1 : 0.4)
        }
        .accessibilityIdentifier("level_row_\(level.id)")
        .buttonStyle(.plain)
        .disabled(!canPlay)
    }

    private func levelRowContent(level: Level, canPlay: Bool) -> some View {
        let remoteUnique = profileVM.levelUniqueSolutionCounts[level.id] ?? 0
        let localUnique = profileVM.solutionCount(for: level)
        let playerStat = profileVM.playerLevelStats[level.id]
        return VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            HStack {
                Text(level.name)
                    .terminalText(16, weight: .medium)
                Spacer()
            }
            Text(level.description)
                .terminalText(14)
                .foregroundColor(HFTheme.Colors.accentDim)
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(HFTheme.Colors.accentSoft)
                if let stat = playerStat {
                    Text("Твои: \(stat.myUniqueSolutions) • Всего: \(remoteUnique)")
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accentDim)
                } else if localUnique > 0 {
                    Text("Твои: \(localUnique) • Всего: \(remoteUnique)")
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accentDim)
                } else {
                    Text("Уникальных решений: \(remoteUnique)")
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accentDim)
                }
            }
            if let stat = playerStat {
                Text("Твой вклад: \(percentText(stat.playerSharePercent)) • Средняя длина: \(lengthText(stat.avgPipelineLength))")
                    .terminalText(12, weight: .semibold)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            if !canPlay {
                Text("Пройди предыдущий уровень")
                    .terminalText(13)
                    .foregroundColor(HFTheme.Colors.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .terminalCard()
    }

}

extension LevelDifficultyListView {
    private func percentText(_ value: Double?) -> String {
        guard let value, !value.isNaN, !value.isInfinite else { return "—" }
        return String(format: "%.1f%%", value)
    }

    private func lengthText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}

struct StatsView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @State private var summaryPage = 0
    @Environment(\.dismiss) private var dismiss

    private struct DifficultySummary: Identifiable {
        let id = UUID()
        let difficulty: LevelDifficulty
        let totalLevels: Int
        let unlocked: Int
        let completed: Int
        let thinkingAvg: Double
        let pipelineRating: String
        let uniqueSolutions: Int
    }

    private var summaries: [DifficultySummary] {
        LevelDifficulty.allCases.compactMap { difficulty in
            let allLevels = Level.all.filter { $0.difficulty == difficulty }
            let unlockedLevels = allLevels.filter { profileVM.isLevelCompleted($0) || profileVM.canPlay(level: $0) }
            guard !unlockedLevels.isEmpty else { return nil }

            let progresses = unlockedLevels.map { profileVM.progress(for: $0) }
            let totalThinking = progresses.reduce(0) { $0 + $1.totalThinkingUnits }
            let completions = progresses.reduce(0) { $0 + $1.totalCompletions }
            let thinkingAvg = completions > 0 ? Double(totalThinking) / Double(completions) : 0
            let completedCount = unlockedLevels.filter { profileVM.isLevelCompleted($0) }.count
            let uniqueSolutions = allLevels.reduce(0) { $0 + profileVM.solutionCount(for: $1) }

            return DifficultySummary(
                difficulty: difficulty,
                totalLevels: allLevels.count,
                unlocked: unlockedLevels.count,
                completed: completedCount,
                thinkingAvg: thinkingAvg,
                pipelineRating: pipelineQuality(for: thinkingAvg),
                uniqueSolutions: uniqueSolutions
            )
        }
    }

    var body: some View {
        let data = summaries
        let safeIndex = min(summaryPage, max(data.count - 1, 0))

        ScrollView {
            if !data.isEmpty {
                VStack(spacing: HFTheme.Spacing.m) {
                    summaryCard(data[safeIndex])
                    levelList(for: data[safeIndex].difficulty)
                    NavigationLink {
                        MyUniqueSolutionsView()
                            .environmentObject(profileVM)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                                Text("Мои уникальные решения")
                                    .terminalText(16, weight: .semibold)
                                Text("Сравни свой вклад с глобальным прогрессом")
                                    .terminalText(13)
                                    .foregroundColor(HFTheme.Colors.accentDim)
                            }
                            Spacer()
                            Image(systemName: "arrow.forward.circle")
                                .foregroundColor(HFTheme.Colors.accentSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .terminalCard()
                    }
                    .buttonStyle(.plain)
                    if data.count > 1 {
                        pagerControls(total: data.count, current: safeIndex)
                    }
                }
                .padding(HFTheme.Spacing.l)
            } else {
                Text("Нет статистики — пройди первый уровень, чтобы она появилась.")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .padding(HFTheme.Spacing.l)
            }
        }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationTitle("Статистика")
        .navigationBarBackButtonHidden(true)
        .applyToolbarBackground()
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .dynamicTypeSize(.medium ... .accessibility5)
        .onChange(of: data.count) { newCount in
            summaryPage = min(summaryPage, max(newCount - 1, 0))
        }
    }

    private func summaryCard(_ summary: DifficultySummary) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
            Text(summary.difficulty.displayName.uppercased())
                .terminalText(18, weight: .semibold)
            HStack(spacing: HFTheme.Spacing.m) {
                statChip(title: "Открыто", value: "\(summary.unlocked)/\(summary.totalLevels)")
                statChip(title: "Решений", value: "\(summary.uniqueSolutions)")
                let thinking = summary.thinkingAvg > 0 ? String(format: "%.1f", summary.thinkingAvg) : "—"
                statChip(title: "Сред. попыток", value: thinking)
            }
            Text(summary.pipelineRating)
                .terminalText(14)
                .foregroundColor(HFTheme.Colors.accentDim)
        }
        .terminalCard()
    }

    private func levelList(for difficulty: LevelDifficulty) -> some View {
        PaginatedLevelList(
            title: "Уровни \(difficulty.displayName.lowercased())",
            levels: Level.all.filter { $0.difficulty == difficulty },
            statusProvider: levelStatus(for:)
        )
        .padding(.top, HFTheme.Spacing.s)
    }

    @ViewBuilder
    private func pagerControls(total: Int, current: Int) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    summaryPage = max(current - 1, 0)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Назад")
                        .terminalText(13, weight: .medium)
                }
            }
            .buttonStyle(.plain)
            .disabled(current == 0)

            Spacer()

            Text("\(current + 1)/\(total)")
                .terminalText(13, weight: .semibold)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    summaryPage = min(current + 1, total - 1)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Вперёд")
                        .terminalText(13, weight: .medium)
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .disabled(current >= total - 1)
        }
        .padding(.top, HFTheme.Spacing.m)
    }

    private func levelStatus(for level: Level) -> (description: String, color: Color) {
        if profileVM.isLevelCompleted(level) {
            let progress = profileVM.progress(for: level)
            let attempts = progress.totalAttempts
            return ("Пройден • попыток: \(attempts)", HFTheme.Colors.accentSoft)
        }
        if profileVM.canPlay(level: level) {
            return ("Доступен к запуску", Color.orange)
        }
        return ("Заблокирован", Color.gray)
    }

    private func pipelineQuality(for thinkingAvg: Double) -> String {
        switch thinkingAvg {
        case 0:
            return "Ещё нет данных: собери хотя бы один пайплайн."
        case ..<8:
            return "Молниеносное мышление — видеокарты завидуют."
        case 8..<16:
            return "Стабильный темп — хорошее соотношение размышлений и действия."
        case 16..<32:
            return "Сложные схемы: мозгу нужно чуть больше времени."
        default:
            return "Пайплайны строятся слишком долго — попробуй упростить конфигурации."
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(HFTheme.Colors.accentDim)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(HFTheme.Colors.accentSoft)
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(HFTheme.Colors.bgPanelSoft)
        )
    }
}

struct MyUniqueSolutionsView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let stats = profileVM.playerLevelStats.values.sorted { $0.levelID < $1.levelID }
        ScrollView {
            VStack(spacing: HFTheme.Spacing.m) {
                header(total: stats.reduce(0) { $0 + $1.myUniqueSolutions })
                if stats.isEmpty {
                    emptyState
                } else {
                    ForEach(stats, id: \.levelID) { stat in
                        statRow(stat)
                    }
                }
            }
            .padding(HFTheme.Spacing.l)
        }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationTitle("Мои уникальные решения")
        .navigationBarBackButtonHidden(true)
        .applyToolbarBackground()
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .task {
            await profileVM.refreshPlayerLevelStats(force: true)
            await profileVM.refreshLevelUniqueSolutionCounts(force: true)
        }
    }

    private func header(total: Int) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("Всего уникальных решений: \(total)")
                .terminalText(18, weight: .bold)
            Text("Каждый пайплайн записан в Supabase. Сравнивайся с глобальным прогрессом и следи за вкладом в уровни.")
                .terminalText(13)
                .foregroundColor(HFTheme.Colors.accentDim)
        }
        .terminalCard()
    }

    private func statRow(_ stat: PlayerLevelStat) -> some View {
        let level = Level.level(withID: stat.levelID)
        return VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            HStack {
                Text(level?.name ?? "Уровень #\(stat.levelID)")
                    .terminalText(16, weight: .medium)
                Spacer()
                Text("ID \(stat.levelID)")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            if let description = level?.description {
                Text(description)
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            HStack {
                statMetric(title: "Твои", value: "\(stat.myUniqueSolutions)")
                statMetric(title: "Всего", value: "\(stat.allUniqueSolutions)")
                statMetric(title: "Доля", value: formattedPercent(stat.playerSharePercent))
                statMetric(title: "Сред. длина", value: formattedLength(stat.avgPipelineLength))
            }
        }
        .terminalCard()
    }

    private func statMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .terminalText(10)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text(value)
                .terminalText(14, weight: .semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedPercent(_ value: Double?) -> String {
        guard let value, !value.isNaN, !value.isInfinite else { return "—" }
        return String(format: "%.1f%%", value)
    }

    private func formattedLength(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private var emptyState: some View {
        VStack(spacing: HFTheme.Spacing.m) {
            Image(systemName: "seal")
                .font(.system(size: 34))
                .foregroundColor(HFTheme.Colors.accent)
            Text("Пока нет уникальных решений.")
                .terminalText(15)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text("Вернись после прохождений — каждое новое уникальное решение попадёт сюда.")
                .terminalText(13)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .terminalCard()
    }
}

private struct PaginatedLevelList: View {
    let title: String
    let levels: [Level]
    let statusProvider: (Level) -> (description: String, color: Color)
    private let pageSize = 8

    @State private var pageIndex: Int = 0
    @State private var showEasterEggAlert = false
    @State private var selectedLevelName: String = ""

    private var pages: [[Level]] {
        levels.chunked(into: pageSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text(title)
                .terminalText(14, weight: .semibold)
            LazyVStack(spacing: HFTheme.Spacing.s) {
                ForEach(currentPageLevels) { level in
                    let status = statusProvider(level)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.name)
                                .terminalText(13, weight: .medium)
                            Text(status.description)
                                .terminalText(11)
                                .foregroundColor(HFTheme.Colors.accentDim)
                        }
                        Spacer()
                        if level.legendHint != nil {
                            Button {
                                showEasterEggInfo(for: level)
                            } label: {
                                Image(systemName: "sparkles")
                                    .foregroundColor(HFTheme.Colors.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Уровень содержит пасхалку")
                        }
                    }
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .padding(.vertical, HFTheme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(status.color.opacity(0.6), lineWidth: 1)
                    )
                }
            }
            .alert("Майнерский слух", isPresented: $showEasterEggAlert) {
                Button("Ок", role: .cancel) { }
            } message: {
                Text(easterEggMessage)
            }

            if pages.count > 1 {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pageIndex = max(pageIndex - 1, 0)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                                .terminalText(12, weight: .medium)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex == 0)

                    Spacer()

                    Text("\(pageIndex + 1)/\(pages.count)")
                        .terminalText(12, weight: .semibold)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pageIndex = min(pageIndex + 1, pages.count - 1)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Вперёд")
                                .terminalText(12, weight: .medium)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex >= pages.count - 1)
                }
                .padding(.vertical, HFTheme.Spacing.xs)
            }
        }
        .onChange(of: levels.count) { _ in
            pageIndex = 0
        }
    }

    private var currentPageLevels: [Level] {
        guard !pages.isEmpty else { return [] }
        return pages[min(pageIndex, pages.count - 1)]
    }

    private var easterEggMessage: String {
        "После прохождения уровня «\(selectedLevelName)» тебя ждёт пасхалка. Дойди до финиша и узнай, что шепчут другие GPU."
    }

    private func showEasterEggInfo(for level: Level) {
        selectedLevelName = level.name
        showEasterEggAlert = true
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count / size) + 1)
        var start = 0
        while start < count {
            let end = Swift.min(start + size, count)
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}

private struct RequirementsSheet: View {
    let title: String
    let description: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                Text(title.uppercased())
                    .terminalText(20, weight: .semibold)
                Text(description)
                    .terminalText(15)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
            .padding(HFTheme.Spacing.l)
        }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
    }
}

private func requirementText(for difficulty: LevelDifficulty, hardcore: Bool) -> String {
    let intro = """
Твоя миссия — проходить уровень за уровнем и доказать ферме майнеров, что у тебя мозг быстрее любой видеокарты. Чтобы добиться TARGET, собирай пайплайн из двух типов узлов:
• XOR — накладывает маску и переворачивает только те биты, где стоят единицы. Пример: 6 (0110₂) XOR 5 (0101₂) = 3 (0011₂).
• SHIFT LEFT — сдвигает число влево и добавляет нули справа. 5 (0101₂) << 1 = 10 (1010₂).

Можно решить задачу одной нодой. Скажем, у тебя INPUT 47, TARGET 224. Достаточно добавить XOR 207: 47 (00101111₂) XOR 207 (11001111₂) = 224 (11100000₂). На учебных уровнях ты сразу видишь, как изменится число, и можешь экспериментировать со значениями. На сложных этапах значения фиксируются, и приходится планировать цепочку заранее. Рецептов бесконечное количество — главное, чтобы финальный Run совпадал с TARGET и улетал в таблицу лидеров.
"""

    let base: String
    switch difficulty {
    case .easy:
        base = """
\(intro)

Режим BASELINE — лаборатория. Тестируй XOR и SHIFT, смотри подсказки и Trace после каждого запуска, фиксируй, как меняется INPUT. Если застрял — используй подсказку: у тебя есть 50 кредитов в день, значит 50 правок цепочек или 5 подсказок. Задача — набить руку и без страха отправлять уникальные пайплайны на сервер, чтобы твой ник появился в leaderboard.
"""
    case .medium:
        base = """
\(intro)

«Средняя мощность» — режим, где подсказки уже не держат тебя за руку. Комбинируй несколько узлов: сначала подгони число SHIFT'ом, потом добей XOR'ом. Следи за Trace, отмечай, какие связки дали прирост, и соревнуйся с другими операторами фермы. Нет идей — потрать подсказку: дневной запас кредитов снова 50, так что можешь потратить 5 подсказок или 50 попыток на чистые эксперименты. Лидерборд мгновенно показывает, кто мыслит быстрее.
"""
    case .asic:
        base = """
\(intro)

«ASIC мышление» — соревновательный режим видеокарты. Здесь ты — GPU, запертый в ферме, и почёт зависит от скорости. Планируй весь пайплайн в голове: представь, какой SHIFT поднимет число в нужный диапазон, каким XOR выровнять хвост, и отправляй только идеальные цепочки. Если совсем упёрся, подсказки всё ещё доступны: дневной резерв 50 кредитов = 50 проверок или 5 подсказок. Каждый запуск влияет на leaderboard — покажи, что твой мозг быстрее любого чипа.
"""
    }

    if hardcore {
        return """
\(base)

Хардкор активирован: узлы блокируются, каждое отклонение бьёт по кредитам, а повторные пайплайны не засчитываются. Это режим для тех, кто хочет доказать, что его мозг-карта сильнее всех. Доставь Target без паники — и твоё имя загорится в верхней части leaderboard.
"""
    } else {
        return base + "\n\nХочешь больше жара? Включай хардкор и покажи всем в leaderboard, что ты умеешь работать без страховки."
    }
}
