import SwiftUI

struct DailyChallengeLevelsView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    let difficulty: DailyDifficulty
    let date: Date

    private var levels: [Level] {
        DailyChallengeGenerator.levels(for: date, difficulty: difficulty)
    }

    @State private var completedIds: Set<Int> = []
    @State private var activeLevel: Level?
    @State private var activeIndex: Int?

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            MatrixRainView().opacity(0.18).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: HFTheme.Spacing.m) {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                        let previousCompleted = index == 0 ? true : completedIds.contains(levels[index - 1].id)
                        let canPlay = previousCompleted

                        Button {
                            guard canPlay else { return }
                            activeLevel = level
                            activeIndex = index
                        } label: {
                            VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                                Text(level.name)
                                    .terminalText(16, weight: .medium)
                                Text(level.description)
                                    .terminalText(14)
                                    .foregroundColor(HFTheme.Colors.accentDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .terminalCard()
                            .opacity(canPlay ? 1 : 0.4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canPlay)
                    }
                }
                .padding(HFTheme.Spacing.l)
            }
        }
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
                Text(difficulty.displayName.uppercased())
                    .terminalText(18, weight: .semibold)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(difficulty.displayName.uppercased())
                    .terminalText(18, weight: .semibold)
            }
        }
        .onAppear {
            completedIds = Set(levels.filter { profileVM.isLevelCompleted($0) }.map { $0.id })
        }
        .fullScreenCover(isPresented: activeLevelBinding) {
            if let binding = levelBinding, let index = activeIndex {
                NavigationView {
                    LevelPlayView(
                        level: binding,
                        dailyLevels: levels,
                        dailyIndex: index,
                        onDailyAdvance: { newIndex in
                            let clamped = min(max(newIndex, 0), levels.count - 1)
                            activeIndex = clamped
                            activeLevel = levels[clamped]
                        }
                    )
                    .environmentObject(profileVM)
                    .onDisappear {
                        if let level = activeLevel {
                            handleCompletion(for: level)
                        }
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            } else {
                EmptyView()
            }
        }
        .dynamicTypeSize(.medium ... .accessibility5)
    }

    private func handleCompletion(for level: Level) {
        if profileVM.isLevelCompleted(level) {
            completedIds.insert(level.id)
            if completedIds.count == levels.count {
                profileVM.markDailyChallengeCompleted(difficulty: difficulty)
            }
        }
    }

    private var activeLevelBinding: Binding<Bool> {
        Binding(
            get: { activeLevel != nil },
            set: { presenting in
                if !presenting {
                    if let level = activeLevel {
                        handleCompletion(for: level)
                    }
                    activeLevel = nil
                    activeIndex = nil
                }
            }
        )
    }

    private var levelBinding: Binding<Level>? {
        guard let activeLevel else { return nil }
        return Binding(
            get: { activeLevel },
            set: { newValue in
                self.activeLevel = newValue
            }
        )
    }
}
