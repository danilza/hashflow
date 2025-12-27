import SwiftUI

struct DailyChallengeMenuView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    private var today: Date { Date() }

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            MatrixRainView().opacity(0.18).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.l) {
                    Text("Выбери испытание на сегодня")
                        .terminalText(18, weight: .semibold)
                    LazyVStack(spacing: HFTheme.Spacing.m) {
                        ForEach(DailyDifficulty.allCases) { difficulty in
                            NavigationLink {
                                DailyChallengeLevelsView(difficulty: difficulty, date: today)
                                    .environmentObject(profileVM)
                            } label: {
                                HStack(alignment: .top, spacing: HFTheme.Spacing.m) {
                                    VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                                        Text(difficulty.displayName)
                                            .terminalText(16, weight: .medium)
                                        Text(difficulty.description)
                                            .terminalText(14)
                                            .foregroundColor(HFTheme.Colors.accentDim)
                                    }
                                    Spacer()
                                    if profileVM.isDailyDifficultyCompletedToday(difficulty) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(HFTheme.Colors.accent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .terminalCard()
                            }
                            .buttonStyle(.plain)
                        }
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
                Text("ЕЖЕДНЕВНОЕ ИСПЫТАНИЕ")
                    .terminalText(18, weight: .semibold)
            }
        }
        .onAppear {
            profileVM.resetDailyMetaIfNeeded()
        }
        .dynamicTypeSize(.medium ... .accessibility5)
    }
}
