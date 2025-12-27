import SwiftUI

struct NFTMarketView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showSettings = false

    private var allPending: [UniquePipelineItem] {
        let combined = profileVM.myPendingSolutions + profileVM.otherPendingSolutions
        let unique = Dictionary(grouping: combined, by: \.pipelineHash)
        return unique.values.compactMap { $0.first }.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            ScrollView {
                VStack(spacing: HFTheme.Spacing.m) {
                    if selectedTab == 0, profileVM.remoteProfile != nil, needsWallet {
                        walletWarning
                    }
                    tabs
                    if selectedTab == 0 {
                        Text("Стоимость минта: 5 кредитов")
                            .terminalText(12)
                            .foregroundColor(HFTheme.Colors.accentDim)
                        pendingList
                    } else {
                        saleList
                    }
                }
                .padding(HFTheme.Spacing.l)
            }
            .interactiveBackGesture()
            .scrollContentBackgroundHidden()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("NFT MARKET")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(HFTheme.Colors.accent)
            }
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView()
                .environmentObject(profileVM)
        }
        .refreshable {
            await profileVM.refreshCreditsAndSolutions()
        }
        .task {
            await profileVM.refreshCreditsAndSolutions()
        }
    }

    private var tabs: some View {
        let items: [(String, Int)] = [
            ("НЕЗАМИНЧЕННЫЕ NFT", 0),
            ("NFT НА ПРОДАЖУ", 1)
        ]
        return HStack(spacing: HFTheme.Spacing.s) {
            ForEach(items, id: \.1) { item in
                let isSelected = selectedTab == item.1
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = item.1
                    }
                } label: {
                    Text(item.0)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? .black : HFTheme.Colors.accentSoft)
                        .padding(.vertical, 10)
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? HFTheme.Colors.accent : HFTheme.Colors.bgPanelSoft)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item.1 == 0 ? "market_tab_pending" : "market_tab_sale")
            }
        }
    }

    private var pendingList: some View {
        return VStack(spacing: HFTheme.Spacing.m) {
            if allPending.isEmpty {
                Text("Пока пусто. Нет незаминченных решений.")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(allPending) { item in
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                        HStack {
                            Text("LEVEL \(item.levelID)")
                                .terminalText(14, weight: .semibold)
                            Spacer()
                            Text(item.ownerID == profileVM.remoteProfile?.id ? "МОЁ" : "ЧУЖОЕ")
                                .terminalText(12)
                                .foregroundColor(HFTheme.Colors.accentDim)
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
                        Button("ЗАМИНТИТЬ") {
                            Task {
                                await profileVM.mintMySolution(item, cost: 5)
                                await profileVM.refreshCreditsAndSolutions()
                            }
                        }
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .padding(.vertical, 10)
                        .background(HFTheme.Colors.accent)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .disabled(needsWallet)
                        .opacity(needsWallet ? 0.5 : 1)
                        .accessibilityIdentifier("market_mint_button")
                    }
                    .padding()
                    .background(HFTheme.Colors.bgPanelSoft)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HFTheme.Colors.accent.opacity(0.3)))
                }
            }
        }
    }

    private var saleList: some View {
        let ownForSale = profileVM.myMintedSolutions.filter { $0.forSale }
        let combined = profileVM.marketSolutions + ownForSale
        let unique = Dictionary(grouping: combined, by: \.pipelineHash).compactMap { $0.value.first }
        return VStack(spacing: HFTheme.Spacing.m) {
            if unique.isEmpty {
                Text("Пока пусто. Нет NFT на продажу.")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(unique) { item in
                    let isMine = item.ownerID == profileVM.remoteProfile?.id
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                        HStack {
                            Text("LEVEL \(item.levelID)")
                                .terminalText(14, weight: .semibold)
                            Spacer()
                            if isMine {
                                Text("МОЁ")
                                    .terminalText(12)
                                    .foregroundColor(HFTheme.Colors.accentDim)
                            }
                        }
                        Text(item.pipelineHash)
                            .terminalText(12)
                            .foregroundColor(HFTheme.Colors.accentSoft)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let price = item.salePrice {
                            Text("Цена: \(price)₵")
                                .terminalText(12, weight: .semibold)
                                .foregroundColor(HFTheme.Colors.accent)
                        }
                        if !isMine {
                            Button("КУПИТЬ") {
                                let price = item.salePrice ?? 0
                                Task {
                                    await profileVM.purchaseSolution(item, price: price)
                                    await profileVM.refreshCreditsAndSolutions()
                                }
                            }
                            .padding(.horizontal, HFTheme.Spacing.m)
                            .padding(.vertical, 10)
                            .background(HFTheme.Colors.accent)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .accessibilityIdentifier("market_buy_button")
                        } else {
                            Text("Ваш NFT в продаже")
                                .terminalText(12)
                                .foregroundColor(HFTheme.Colors.accentDim)
                        }
                    }
                    .padding()
                    .background(HFTheme.Colors.bgPanelSoft)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HFTheme.Colors.accent.opacity(0.3)))
                }
            }
        }
    }

    private var needsWallet: Bool {
        let wallet = profileVM.remoteProfile?.walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return wallet.isEmpty
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
        .accessibilityIdentifier("wallet_required_banner")
    }
}
