import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @EnvironmentObject var sessionStore: SessionStore

    private let authService = AuthService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)

                SecureField("パスワード", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUpMode ? "新規登録" : "ログイン")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)

                Button {
                    isSignUpMode.toggle()
                    errorMessage = nil
                } label: {
                    Text(isSignUpMode ? "既にアカウントをお持ちの方はこちら" : "アカウントをお持ちでない方はこちら")
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(isSignUpMode ? "新規登録" : "ログイン")
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUpMode {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            await sessionStore.refreshSessionState()
        } catch {
            // ここで Supabase の生のエラーを出す
            print("Auth error: \(error)")

            await MainActor.run {
                // 表示用のメッセージはこのままでOK
                errorMessage = "認証に失敗しました。メールアドレスとパスワードをご確認ください。"
            }
        }
    }
}
