import SwiftUI

struct UniqueSolutionsView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var mintingId: String?
    @State private var showSettings = false
    @State private var now = Date()
    @State private var selectedIds: Set<String> = []
    @State private var selectAll = false

    var body: some View {
        ScrollView {
            VStack(spacing: HFTheme.Spacing.m) {
                header
                if shouldShowWalletWarning {
                    walletWarning
                }
                if let err = profileVM.supabaseError {
                    Text(err)
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, HFTheme.Spacing.xs)
                } else if let info = profileVM.supabaseInfo {
                    Text(info)
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, HFTheme.Spacing.xs)
                }
                Text("МОИ НЕЗАМИНЧЕННЫЕ")
                    .terminalText(12, weight: .semibold)
                    .foregroundColor(HFTheme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Button {
                        selectAll.toggle()
                        if selectAll {
                            selectedIds = Set(profileVM.myPendingSolutions.map { $0.id })
                        } else {
                            selectedIds.removeAll()
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectAll ? "checkmark.square.fill" : "square")
                            Text("Выделить все")
                                .terminalText(12, weight: .semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if !selectedIds.isEmpty {
                        Button {
                            Task { await mintSelected() }
                        } label: {
                            Text("ЗАМИНТИТЬ ВЫДЕЛЕННЫЕ")
                                .terminalText(12, weight: .semibold)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Text("Стоимость минта: 5 кредитов")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                content
            }
            .padding(HFTheme.Spacing.l)
        }
        .interactiveBackGesture { dismiss() }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationTitle("UNIQUE SOLUTIONS")
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("UNIQUE SOLUTIONS")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(HFTheme.Colors.accent)
            }
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView()
                .environmentObject(profileVM)
        }
        .refreshable {
            await reload()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
        .task {
            await reload()
        }
    }

    private func mintSelected() async {
        // Минимальный контроль: минтим все отмеченные, по одному.
        let ids = selectedIds
        for item in profileVM.myPendingSolutions where ids.contains(item.id) {
            await profileVM.mintMySolution(item, cost: 5)
        }
        await reload()
        await MainActor.run {
            mintingId = nil
            selectedIds.removeAll()
            selectAll = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            HStack {
                Text("ХОДЫ И КРЕДИТЫ")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
                if profileVM.isFreeRunActive {
                    Text("FREE-RUN АКТИВЕН")
                        .terminalText(12, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accent)
                }
                Spacer()
            }
            HStack(spacing: HFTheme.Spacing.l) {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                    Text("ХОДОВ ОСТАЛОСЬ")
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accentDim)
                    Text("\(profileVM.movesBalance ?? 0)")
                        .terminalText(22, weight: .bold)
                }
                VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                    Text("КРЕДИТОВ")
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accentDim)
                    Text("\(profileVM.creditBalance ?? 0)")
                        .terminalText(18, weight: .semibold)
                        .foregroundColor(HFTheme.Colors.accentSoft)
                }
                VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                    Text("ВЫВОД")
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accentDim)
                    Text("\(profileVM.withdrawableBalance ?? 0)")
                        .terminalText(14, weight: .medium)
                        .foregroundColor(HFTheme.Colors.accentSoft)
                }
                Spacer()
            }
            if let countdown = profileVM.creditRefillCountdown {
                Text("ХОДЫ ОБНОВЯТСЯ ЧЕРЕЗ \(countdown)")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
        }
        .terminalCard()
    }

    private var needsWallet: Bool {
        if let forced = ProcessInfo.processInfo.environment["UITEST_WALLET_ADDRESS"], forced.isEmpty {
            return true
        }
        let wallet = profileVM.remoteProfile?.walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return wallet.isEmpty
    }

    private var shouldShowWalletWarning: Bool {
        guard needsWallet else { return false }
        if profileVM.remoteProfile != nil { return true }
        return ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }

    private var walletWarning: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("Для операций с NFT нужен адрес кошелька.")
                .terminalText(13, weight: .semibold)
            Button {
                showSettings = true
            } label: {
                Text("УКАЗАТЬ КОШЕЛЁК")
                    .terminalText(12, weight: .semibold)
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .padding(.vertical, 8)
                    .background(HFTheme.Colors.accent)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .accessibilityIdentifier("wallet_settings_button")
        }
        .padding()
        .background(HFTheme.Colors.bgPanelSoft)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.6)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wallet_required_banner")
    }

    private var content: some View {
        Group {
            if profileVM.remoteProfile == nil {
                Text("Войдите, чтобы увидеть и заминтить решения.")
                    .terminalText(14)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                solutionsList(items: profileVM.myPendingSolutions, actionTitle: "ЗАМИНТИТЬ", enabled: !needsWallet, mintingId: $mintingId, selectedIds: $selectedIds)
            }
        }
    }

    @ViewBuilder
    private func solutionsList(
        items: [UniquePipelineItem],
        actionTitle: String,
        enabled: Bool = true,
        mintingId: Binding<String?>,
        selectedIds: Binding<Set<String>>
    ) -> some View {
        if items.isEmpty {
            Text("Пока пусто. Решай уровни или обнови список.")
                .terminalText(14)
                .foregroundColor(HFTheme.Colors.accentDim)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: HFTheme.Spacing.m) {
                ForEach(items) { item in
                    solutionRow(item: item, actionTitle: actionTitle, enabled: enabled, mintingId: mintingId, selectedIds: selectedIds)
                }
            }
        }
    }

    private func solutionRow(
        item: UniquePipelineItem,
        actionTitle: String,
        enabled: Bool,
        mintingId: Binding<String?>,
        selectedIds: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            HStack {
                Button {
                    if selectedIds.wrappedValue.contains(item.id) {
                        selectedIds.wrappedValue.remove(item.id)
                    } else {
                        selectedIds.wrappedValue.insert(item.id)
                    }
                    selectAll = selectedIds.wrappedValue.count == profileVM.myPendingSolutions.count
                } label: {
                    Image(systemName: selectedIds.wrappedValue.contains(item.id) ? "checkmark.square.fill" : "square")
                        .foregroundColor(HFTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                Text("LEVEL \(item.levelID)")
                    .terminalText(14, weight: .semibold)
                Spacer()
                if let status = item.nftStatus?.uppercased() {
                    Text(status)
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accent)
                }
            }
            Text(item.pipelineHash)
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentSoft)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack {
                Text("Длина: \(item.pipelineLength)")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
                if let date = item.createdAt {
                    Text(date, style: .date)
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accentDim)
                }
            }
        }
        .padding()
        .background(HFTheme.Colors.bgPanelSoft)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HFTheme.Colors.accent.opacity(0.3)))
    }

    private func reload() async {
        if isLoading { return }
        isLoading = true
        await profileVM.refreshCreditsAndSolutions()
        isLoading = false
    }
}
