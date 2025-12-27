import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var viewModel: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isSavingTon = false
    @State private var isSigningOut = false
    @State private var showDeleteAlert = false
    @State private var walletAddress: String = ""

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    settingsContent
                }
            } else {
                NavigationView {
                    settingsContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .onAppear {
            username = viewModel.remoteProfile?.username ?? ""
            walletAddress = viewModel.remoteProfile?.walletAddress ?? ""
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.l) {
            Text("Hash Flow ID")
                .terminalText(18, weight: .semibold)

            VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                Text("ТЕКУЩИЙ НИК")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
                TextField("", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .padding(.vertical, HFTheme.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundColor(HFTheme.Colors.accentSoft)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
            }

            tonWalletSection
            if let message = statusMessage {
                Text(message)
                    .terminalText(13)
                    .foregroundColor(HFTheme.Colors.accent)
            }

            if let error = errorMessage {
                Text(error)
                    .terminalText(13)
                    .foregroundColor(.orange)
            }

            VStack(spacing: HFTheme.Spacing.s) {
                Button(action: saveUsername) {
                    Text(isSaving ? "СОХРАНЯЕМ…" : "СОХРАНИТЬ НИК")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HFTheme.Colors.accent)
                        .cornerRadius(14)
                }
                .disabled(isSaving || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    signOut()
                } label: {
                    Text(isSigningOut ? "ВЫХОД…" : "ВЫЙТИ")
                        .terminalText(15, weight: .semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.8), lineWidth: 1)
                        )
                }
                .disabled(isSigningOut)

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("Удалить аккаунт")
                        .terminalText(15, weight: .semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.8), lineWidth: 1)
                        )
                }
            }

            Spacer()
        }
        .padding(HFTheme.Spacing.xl)
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
                .terminalText(14, weight: .semibold)
            }
        }
        .navigationTitle("Профиль")
        .alert("Удалить аккаунт?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) {
                deleteAccount()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Все прогрессы и записи в таблице лидеров будут стерты. Операция необратима.")
        }
    }

    private func saveUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Ник не может быть пустым."
            statusMessage = nil
            return
        }
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        Task {
            do {
                try await viewModel.updateUsername(to: trimmed)
                await MainActor.run {
                    isSaving = false
                    statusMessage = "Ник обновлён."
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var tonWalletSection: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("TON-КОШЕЛЁК")
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentDim)
            TextField("UQ....", text: $walletAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .padding(.horizontal, HFTheme.Spacing.m)
                .padding(.vertical, HFTheme.Spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
                .foregroundColor(HFTheme.Colors.accentSoft)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .accessibilityIdentifier("wallet_address_field")
            Text("Этот адрес будет использоваться для привязки NFT решений.")
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentDim)
            Button(action: saveTonAddress) {
                Text(isSavingTon ? "СОХРАНЯЕМ…" : "СОХРАНИТЬ TON-АДРЕС")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HFTheme.Colors.accent.opacity(0.8))
                    .cornerRadius(14)
            }
            .disabled(isSavingTon)
            .accessibilityIdentifier("wallet_save_button")
        }
    }

    private func saveTonAddress() {
        isSavingTon = true
        errorMessage = nil
        statusMessage = nil
        let normalized = SupabaseService.normalizeWalletAddress(walletAddress)
        Task {
            do {
                try await viewModel.updateWalletAddress(to: normalized)
                await MainActor.run {
                    isSavingTon = false
                    walletAddress = normalized ?? ""
                    statusMessage = "TON-кошелёк сохранён."
                }
            } catch {
                await MainActor.run {
                    isSavingTon = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        errorMessage = nil
        statusMessage = nil
        Task {
            do {
                try await viewModel.signOut()
                await MainActor.run {
                    isSigningOut = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSigningOut = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteAccount() {
        isSigningOut = true
        errorMessage = nil
        statusMessage = nil
        Task {
            await viewModel.deleteAccount()
            await MainActor.run {
                isSigningOut = false
                dismiss()
            }
        }
    }
}
