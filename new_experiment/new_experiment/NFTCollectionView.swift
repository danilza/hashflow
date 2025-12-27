import SwiftUI
import UIKit

struct NFTCollectionView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNFT: SolutionNFT?

    var body: some View {
        ScrollView {
            VStack(spacing: HFTheme.Spacing.l) {
                if profileVM.myMintedSolutions.isEmpty {
                    emptyState
                } else {
                    ForEach(profileVM.myMintedSolutions) { item in
                        nftCard(for: item)
                    }
                }
            }
            .padding(HFTheme.Spacing.l)
        }
        .interactiveBackGesture()
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .navigationTitle("My NFT Collection")
        .navigationBarBackButtonHidden(true)
        .applyToolbarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarNavButton(title: "Назад", systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedNFT) { nft in
            NFTDetailView(nft: nft)
        }
        .refreshable {
            await profileVM.refreshCreditsAndSolutions()
            await profileVM.refreshPlayerNFTs(force: true)
        }
        .task {
            await profileVM.refreshCreditsAndSolutions()
            await profileVM.refreshPlayerNFTs(force: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: HFTheme.Spacing.m) {
            Image(systemName: "seal")
                .font(.system(size: 40))
                .foregroundColor(HFTheme.Colors.accent)
            Text("Ещё нет NFT-решений")
                .terminalText(16, weight: .semibold)
            Text("Проходи уровни и открывай уникальные пайплайны, чтобы коллекция ожила.")
                .terminalText(14)
                .multilineTextAlignment(.center)
                .foregroundColor(HFTheme.Colors.accentDim)
        }
        .padding()
        .terminalCard()
    }

    private func nftCard(for item: UniquePipelineItem) -> some View {
        let overlay = profileVM.playerNFTs.first(where: { $0.pipelineHash == item.pipelineHash })
        let address = overlay?.nftAddress ?? item.nftAddress
        return VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("Уровень \(item.levelID)")
                .terminalText(16, weight: .semibold)
            if let name = overlay?.chainMetadataName, !name.isEmpty {
                Text(name)
                    .terminalText(14, weight: .medium)
            }
            Text("Hash: \(item.pipelineHash.prefix(12))…")
                .terminalText(13)
                .foregroundColor(HFTheme.Colors.accentDim)
            if let mintedAt = overlay?.mintedAt {
                Text("Минт: \(mintedAt.formatted(date: .abbreviated, time: .shortened))")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            if let imageURL = overlay?.chainMetadataImage.flatMap(TonLinks.normalizedImageURL(from:)) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(HFTheme.Colors.bgPanelSoft.opacity(0.4))
                        .frame(height: 140)
                        .overlay(ProgressView().tint(.white))
                }
            }
            if let overlay {
                ownershipStatus(for: overlay)
            }
            if let address {
                Text(address)
                    .terminalText(12, weight: .semibold)
                    .foregroundColor(HFTheme.Colors.accent)
                actionButtons(for: overlay, address: address)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .terminalCard()
        .contentShape(Rectangle())
        .onTapGesture {
            if let overlay {
                selectedNFT = overlay
            }
        }
    }

    private func ownershipStatus(for nft: SolutionNFT) -> some View {
        let text: String
        let color: Color
        switch nft.isOwnedByCurrentPlayer {
        case .some(true):
            text = "NFT подтверждён на твоём кошельке"
            color = HFTheme.Colors.accent
        case .some(false):
            text = "NFT передан другому адресу"
            color = .orange
        case .none:
            text = "Не удалось проверить владельца"
            color = HFTheme.Colors.accentDim
        }
        return Text(text)
            .terminalText(12)
            .foregroundColor(color)
    }

    private func actionButtons(for nft: SolutionNFT?, address: String) -> some View {
        let showTransfer = nft?.isOwnedByCurrentPlayer == true
        let validAddress = isValidTonAddress(address)
        return HStack(spacing: HFTheme.Spacing.m) {
            if validAddress {
                Button {
                    open(url: TonLinks.tonViewerURL(for: address))
                } label: {
                    Text("TONVIEWER")
                        .terminalText(12, weight: .semibold)
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .padding(.vertical, 8)
                        .background(HFTheme.Colors.bgPanelSoft)
                        .foregroundColor(HFTheme.Colors.accent)
                        .cornerRadius(10)
                }
            }

            if showTransfer, validAddress {
                Button {
                    open(url: TonLinks.transferURL(for: address))
                } label: {
                    Text("ПЕРЕДАТЬ")
                        .terminalText(12, weight: .semibold)
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .padding(.vertical, 8)
                        .background(HFTheme.Colors.accent)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
        }
    }

    private func open(url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func isValidTonAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("EQ") || trimmed.hasPrefix("UQ")) && trimmed.count > 30
    }

}

private struct NFTDetailView: View {
    let nft: SolutionNFT

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                    Text("Уровень \(nft.levelID)")
                        .terminalText(20, weight: .bold)
                    if let name = nft.chainMetadataName, !name.isEmpty {
                        Text(name)
                            .terminalText(16, weight: .semibold)
                    }
                    ownershipStatus(for: nft)
                    if let imageURL = nft.chainMetadataImage.flatMap(TonLinks.normalizedImageURL(from:)) {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(16)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(HFTheme.Colors.bgPanelSoft.opacity(0.4))
                                .frame(height: 200)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    if let address = nft.nftAddress {
                        detailRow(title: "NFT адрес", value: address)
                    }
                    if let tx = nft.mintTxHash {
                        detailRow(title: "TX", value: tx)
                    }
                    detailRow(title: "Длина пайплайна", value: "\(nft.pipelineLength)")
                    detailRow(title: "Hash", value: nft.pipelineHash)
                    if let metadata = nft.metadataURI {
                        detailRow(title: "Metadata", value: metadata)
                    }
                    if let mintedAt = nft.mintedAt {
                        detailRow(title: "Дата", value: mintedAt.formatted(date: .complete, time: .shortened))
                    }
                    if let address = nft.nftAddress {
                        HStack(spacing: HFTheme.Spacing.m) {
                            if isValidTonAddress(address) {
                                Button {
                                    if let url = TonLinks.tonViewerURL(for: address) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("TONVIEWER")
                                        .terminalText(12, weight: .semibold)
                                        .padding(.horizontal, HFTheme.Spacing.m)
                                        .padding(.vertical, 8)
                                        .background(HFTheme.Colors.bgPanelSoft)
                                        .foregroundColor(HFTheme.Colors.accent)
                                        .cornerRadius(10)
                                }
                            }
                            if nft.isOwnedByCurrentPlayer == true, isValidTonAddress(address) {
                                Button {
                                    if let url = TonLinks.transferURL(for: address) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("ПЕРЕДАТЬ")
                                        .terminalText(12, weight: .semibold)
                                        .padding(.horizontal, HFTheme.Spacing.m)
                                        .padding(.vertical, 8)
                                        .background(HFTheme.Colors.accent)
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("NFT #\(nft.pipelineHash.prefix(6))")
            .navigationBarTitleDisplayMode(.inline)
            .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        }
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .terminalText(11)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text(value)
                .terminalText(15)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = value
                    } label: {
                        Label("Скопировать", systemImage: "doc.on.doc")
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .terminalCard()
    }

    private func ownershipStatus(for nft: SolutionNFT) -> some View {
        let text: String
        let color: Color
        switch nft.isOwnedByCurrentPlayer {
        case .some(true):
            text = "NFT закреплён за твоим кошельком"
            color = HFTheme.Colors.accent
        case .some(false):
            text = "NFT уже принадлежит другому адресу"
            color = .orange
        case .none:
            text = "Не удалось проверить владельца"
            color = HFTheme.Colors.accentDim
        }
        return Text(text)
            .terminalText(13, weight: .medium)
            .foregroundColor(color)
    }

    private func isValidTonAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("EQ") || trimmed.hasPrefix("UQ")) && trimmed.count > 30
    }
}
