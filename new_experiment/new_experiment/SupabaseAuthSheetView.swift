import SwiftUI

struct SupabaseAuthSheetView: View {
    @ObservedObject var viewModel: GameProfileViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isProcessing = false
    @State private var showAnonAlert = false
    @State private var otpCode = ""
    @State private var showRegistration = false
    @State private var registerEmail = ""
    @State private var registerUsername = ""
    @State private var registerPassword = ""
    @State private var registerConfirm = ""
    @State private var registerError: String?
    @State private var registerSuggestedUsername = SupabaseAuthSheetView.randomUsername()

    var body: some View {
        presentedStack
        .alert("Точно анонимно?", isPresented: $showAnonAlert) {
            Button("Да, продолжить") {
                viewModel.continueAnonymously()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Анонимы не участвуют в турнирах и рейтингах. Это шанс побороть социофобию!")
        }
        .dynamicTypeSize(.medium ... .accessibility5)
    }

    @ViewBuilder
    private var presentedStack: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                currentContent
            }
        } else {
            NavigationView {
                currentContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    @ViewBuilder
    private var currentContent: some View {
        if viewModel.pendingOtpEmail != nil {
            otpContent
        } else if showRegistration {
            registrationContent
        } else {
            authContent
        }
    }

    private var authContent: some View {
        VStack(spacing: HFTheme.Spacing.l) {
            Text("Hash Flow ID")
                .terminalText(20, weight: .semibold)
            VStack(spacing: HFTheme.Spacing.m) {
                terminalField(title: "email", text: $email, keyboard: .emailAddress, contentType: .emailAddress, identifier: "auth_email")
                terminalField(title: "пароль", text: $password, isSecure: true, keyboard: .default, contentType: .password, identifier: "auth_password")
            }
            if let error = viewModel.supabaseError {
                Text(error)
                    .terminalText(13)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let info = viewModel.supabaseInfo {
                Text(info)
                    .terminalText(13)
                    .foregroundColor(HFTheme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: HFTheme.Spacing.s) {
                Button {
                    authAction {
                        await viewModel.signIn(email: email, password: password)
                    }
                } label: {
                    authButtonLabel(text: "Войти", textColor: .black)
                }
                .accessibilityIdentifier("auth_login_button")
                Button {
        showRegistration = true
        registerEmail = email
        registerSuggestedUsername = SupabaseAuthSheetView.randomUsername()
        registerPassword = ""
        registerConfirm = ""
        registerUsername = ""
        registerError = nil
                } label: {
                    authButtonLabel(text: "Нет аккаунта? Зарегистрироваться", invert: true)
                }
                .accessibilityIdentifier("auth_register_toggle")
                Button {
                    showAnonAlert = true
                } label: {
                    Text("Войти анонимно")
                        .terminalText(14, weight: .semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.8), lineWidth: 1)
                        )
                }
                .accessibilityIdentifier("auth_anon_button")
                Button {
                    googleAction()
                } label: {
                    authButtonLabel(text: "Google", invert: true)
                }
                .accessibilityIdentifier("auth_google_button")
            }
            .disabled(isProcessing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(HFTheme.Spacing.l)
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Аутентификация")
                    .terminalText(16, weight: .semibold)
            }
        }
    }

    private var registrationContent: some View {
        VStack(spacing: HFTheme.Spacing.l) {
            Text("Регистрация")
                .terminalText(20, weight: .semibold)
            VStack(spacing: HFTheme.Spacing.m) {
                terminalField(title: "ник", text: $registerUsername, keyboard: .default, contentType: .username, placeholder: registerSuggestedUsername, identifier: "register_username")
                terminalField(title: "email", text: $registerEmail, keyboard: .emailAddress, contentType: .emailAddress, identifier: "register_email")
                terminalField(title: "пароль", text: $registerPassword, isSecure: true, keyboard: .default, contentType: .password, identifier: "register_password")
                terminalField(title: "подтверди пароль", text: $registerConfirm, isSecure: true, keyboard: .default, contentType: .password, identifier: "register_confirm")
            }
            if let error = registerError {
                Text(error)
                    .terminalText(13)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = viewModel.supabaseError {
                Text(error)
                    .terminalText(13)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                registerAction()
            } label: {
                authButtonLabel(text: "Зарегистрировать", textColor: .black)
            }
            .disabled(isProcessing)
            .accessibilityIdentifier("register_submit")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(HFTheme.Spacing.l)
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Назад") {
                    showRegistration = false
                    registerError = nil
                }
                .terminalText(14, weight: .semibold)
            }
            ToolbarItem(placement: .principal) {
                Text("Регистрация")
                    .terminalText(16, weight: .semibold)
            }
        }
        .onChange(of: registerUsername) { _ in
            registerError = nil
        }
    }

    private var otpContent: some View {
        VStack(spacing: HFTheme.Spacing.l) {
            Text("ПОДТВЕРДИ ПОЧТУ")
                .terminalText(20, weight: .semibold)
            if let email = viewModel.pendingOtpEmail {
                Text("Мы отправили шестизначный код на \(email). Введи его, чтобы активировать аккаунт.")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                Text("КОД")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentDim)
                TextField("123456", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .foregroundColor(HFTheme.Colors.accentSoft)
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .padding(.vertical, HFTheme.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: otpCode) { newValue in
                        let digits = newValue.filter(\.isWholeNumber)
                        let limited = String(digits.prefix(6))
                        if limited != newValue {
                            otpCode = limited
                        }
                    }
                    .accessibilityIdentifier("otp_code")
            }
            if let error = viewModel.supabaseError {
                Text(error)
                    .terminalText(13)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let info = viewModel.supabaseInfo {
                Text(info)
                    .terminalText(13)
                    .foregroundColor(HFTheme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                googleAction()
            } label: {
                authButtonLabel(text: "Войти через Google", invert: true)
            }
            .accessibilityIdentifier("otp_google_button")
            Button {
                otpAction()
            } label: {
                authButtonLabel(text: "Подтвердить", textColor: .black)
            }
            .disabled(isProcessing || otpCode.count != 6)
            .accessibilityIdentifier("otp_confirm")

            Button {
                otpCode = ""
                viewModel.cancelOtpFlow()
            } label: {
                Text("Изменить email")
                    .terminalText(13, weight: .semibold)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(HFTheme.Spacing.l)
        .background(HFTheme.Colors.bgMain.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Назад") {
                    otpCode = ""
                    viewModel.cancelOtpFlow()
                    showRegistration = true
                }
                .terminalText(14, weight: .semibold)
            }
            ToolbarItem(placement: .principal) {
                Text("Подтверждение")
                    .terminalText(16, weight: .semibold)
            }
        }
    }

    private func terminalField(title: String, text: Binding<String>, isSecure: Bool = false, keyboard: UIKeyboardType, contentType: UITextContentType, placeholder: String? = nil, identifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
            Text(title.uppercased())
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentDim)
            if isSecure {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text(verbatim: "••••••••")
                            .foregroundColor(HFTheme.Colors.accentSoft.opacity(0.5))
                            .padding(.horizontal, HFTheme.Spacing.m)
                            .padding(.vertical, HFTheme.Spacing.s)
                    }
                    SecureField("", text: text)
                        .foregroundColor(HFTheme.Colors.accentSoft)
                        .textContentType(contentType)
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .padding(.vertical, HFTheme.Spacing.s)
                        .keyboardType(keyboard)
                        .accessibilityIdentifier(identifier ?? "")
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
            } else {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text(verbatim: placeholder ?? "mail@hashflow.app")
                            .foregroundColor(HFTheme.Colors.accentSoft.opacity(0.5))
                            .padding(.horizontal, HFTheme.Spacing.m)
                            .padding(.vertical, HFTheme.Spacing.s)
                    }
                    TextField("", text: text)
                        .foregroundColor(HFTheme.Colors.accentSoft)
                        .textContentType(contentType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(keyboard)
                        .padding(.horizontal, HFTheme.Spacing.m)
                        .padding(.vertical, HFTheme.Spacing.s)
                        .accessibilityIdentifier(identifier ?? "")
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    private func authButtonLabel(text: String, invert: Bool = false, textColor: Color = HFTheme.Colors.accent) -> some View {
        Text(text.uppercased())
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding()
            .background(invert ? Color.clear : HFTheme.Colors.accent)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(HFTheme.Colors.accent.opacity(invert ? 0.8 : 0), lineWidth: 1)
            )
            .foregroundColor(invert ? HFTheme.Colors.accent : textColor)
            .cornerRadius(14)
    }

    private func authAction(_ action: @escaping () async -> Void) {
        guard !email.isEmpty, !password.isEmpty else { return }
        isProcessing = true
        Task {
            await action()
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func otpAction() {
        guard otpCode.count == 6 else {
            viewModel.supabaseError = "Введи все 6 цифр кода из письма."
            return
        }
        isProcessing = true
        Task {
            await viewModel.confirmEmailOtp(code: otpCode)
            await MainActor.run {
                isProcessing = false
                otpCode = ""
            }
        }
    }

    private func registerAction() {
        guard !registerEmail.isEmpty else {
            registerError = "Укажи email."
            return
        }
        var trimmedUsername = registerUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername.isEmpty {
            trimmedUsername = registerSuggestedUsername
        }
        guard !registerPassword.isEmpty else {
            registerError = "Придумай пароль."
            return
        }
        guard registerPassword == registerConfirm else {
            registerError = "Пароли не совпадают."
            return
        }
        registerError = nil
        isProcessing = true
        Task {
            do {
                let available = try await SupabaseService.shared.isUsernameAvailable(trimmedUsername)
                guard available else {
                    await MainActor.run {
                        registerError = "Ник уже занят."
                        isProcessing = false
                    }
                    return
                }
                await viewModel.signUp(email: registerEmail, password: registerPassword, username: trimmedUsername)
            } catch {
                await MainActor.run {
                    registerError = error.localizedDescription
                }
            }
            await MainActor.run {
                isProcessing = false
                if viewModel.pendingOtpEmail != nil {
                    email = registerEmail
                    password = registerPassword
                    registerUsername = trimmedUsername
                    showRegistration = false
                }
            }
        }
    }

    private func googleAction() {
        viewModel.cancelOtpFlow()
        isProcessing = true
        Task {
            await viewModel.signInWithGoogle()
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

extension SupabaseAuthSheetView {
    static func randomUsername() -> String {
        "Player\(Int.random(in: 1000...9999))"
    }
}
