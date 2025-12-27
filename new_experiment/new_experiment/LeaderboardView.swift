import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HFTheme.Spacing.m, pinnedViews: []) {
                headerRow
                if profileVM.leaderboardEntries.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(zip(profileVM.leaderboardEntries.indices,
                                      profileVM.leaderboardEntries)),
                            id: \.0) { index, entry in
                        rowView(position: index + 1, entry: entry)
                    }
                }
            }
            .padding(HFTheme.Spacing.l)
        }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationTitle("Таблица лидеров")
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
            await profileVM.refreshLeaderboard()
        }
    }

    private var headerRow: some View {
        HStack {
            Text("#")
                .terminalText(13, weight: .semibold)
                .frame(width: 30, alignment: .leading)
            Text("ИГРОК")
                .terminalText(13, weight: .semibold)
            Spacer()
            Text("УНИК. Р-Я")
                .terminalText(13, weight: .semibold)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HFTheme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func rowView(position: Int, entry: LeaderboardEntry) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
            HStack {
                Text("\(position).")
                    .terminalText(15, weight: .medium)
                    .frame(width: 30, alignment: .leading)
                Text(entry.username.uppercased())
                    .terminalText(16, weight: .semibold)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(entry.uniqueSolutions) решений")
                        .terminalText(16, weight: .bold)
                        .foregroundColor(HFTheme.Colors.accent)
                    if let respect = entry.respect {
                        Text("Респект: \(respect)")
                            .terminalText(12)
                            .foregroundColor(HFTheme.Colors.accentDim)
                    }
                }
                .frame(width: 110, alignment: .trailing)
            }
            if let date = entry.updatedAt {
                Text("Последнее обновление: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .terminalText(11)
                    .foregroundColor(.gray)
            } else {
                Text("Уникальные решения: \(entry.uniqueSolutions)")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(HFTheme.Colors.accent.opacity(0.2), lineWidth: 1)
                .background(
                    HFTheme.Colors.bgPanelSoft.cornerRadius(16)
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: HFTheme.Spacing.m) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 34))
                .foregroundColor(HFTheme.Colors.accent)
            Text("Ещё никто не отправил результат.")
                .terminalText(15)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text("Проходи уровни, отправляй уникальные решения — и появись в таблице!")
                .terminalText(13)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(HFTheme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
