import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false
    @State private var errorMessage: String?

    @EnvironmentObject var sessionStore: SessionStore

    private let authService = AuthService.shared
    
    // Instagram Colors
    private let instagramGradient = LinearGradient(
        colors: [
            Color(red: 131/255, green: 58/255, blue: 180/255),
            Color(red: 253/255, green: 29/255, blue: 29/255),
            Color(red: 252/255, green: 176/255, blue: 69/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let disabledGradient = LinearGradient(
        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)
    private let borderGray = Color(red: 219/255, green: 219/255, blue: 219/255)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    // MARK: - Logo Section
                    logoSection
                    
                    Spacer().frame(height: 32)
                    
                    // MARK: - Mode Title
                    modeTitle
                    
                    Spacer().frame(height: 24)
                    
                    // MARK: - Input Fields
                    inputSection
                    
                    Spacer().frame(height: 20)
                    
                    // MARK: - Submit Button
                    submitButton
                    
                    Spacer().frame(height: 24)
                    
                    // MARK: - Divider
                    dividerSection
                    
                    Spacer().frame(height: 20)
                    
                    // MARK: - Social Login Buttons
                    socialLoginSection
                    
                    Spacer().frame(height: 24)
                    
                    // MARK: - Guest Mode Button
                    guestModeButton
                    
                    Spacer().frame(height: 40)
                    
                    // MARK: - Bottom Switch
                    bottomSwitch
                }
                .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(instagramGradient)
            }
            
            Text("aikotoba")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .italic()
            
            Text("秘密の合言葉で繋がる")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Mode Title
    private var modeTitle: some View {
        VStack(spacing: 8) {
            Text(isSignUpMode ? "アカウント作成" : "ログイン")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(isSignUpMode ? "メールアドレスで新しいアカウントを作成" : "既存のアカウントでログイン")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // メールアドレス
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(14)
            .background(subtleGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGray, lineWidth: 1)
            )
            
            // パスワード
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField(isSignUpMode ? "パスワード（6文字以上）" : "パスワード", text: $password)
            }
            .padding(14)
            .background(subtleGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGray, lineWidth: 1)
            )
            
            // パスワード確認（新規登録時のみ）
            if isSignUpMode {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    SecureField("パスワード（再入力）", text: $confirmPassword)
                }
                .padding(14)
                .background(subtleGray)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(passwordsMatch ? borderGray : Color.red.opacity(0.5), lineWidth: 1)
                )
                
                // パスワード不一致の警告
                if !confirmPassword.isEmpty && !passwordsMatch {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                        Text("パスワードが一致しません")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // エラーメッセージ
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isSignUpMode ? "person.badge.plus" : "arrow.right.circle")
                    Text(isSignUpMode ? "アカウントを作成する" : "ログインする")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? instagramGradient : disabledGradient)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!canSubmit || isLoading)
    }
    
    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(borderGray)
                .frame(height: 1)
            
            Text("または")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(borderGray)
                .frame(height: 1)
        }
    }
    
    // MARK: - Social Login Section
    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            // Apple Sign-In
            Button {
                Task { await signInWithApple() }
            } label: {
                HStack(spacing: 8) {
                    if isAppleLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18))
                        Text("Appleで続ける")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isAppleLoading || isGoogleLoading)
            
            // Google Sign-In
            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: 8) {
                    if isGoogleLoading {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        GoogleLogoView()
                        Text("Googleで続ける")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .foregroundColor(.primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderGray, lineWidth: 1)
                )
            }
            .disabled(isAppleLoading || isGoogleLoading)
        }
    }
    
    // MARK: - Guest Mode Button
    private var guestModeButton: some View {
        Button {
            sessionStore.enterGuestMode()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 16))
                Text("ゲストモードで続ける")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(.secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGray, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Bottom Switch
    private var bottomSwitch: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 4) {
                Text(isSignUpMode ? "既にアカウントをお持ちですか？" : "アカウントをお持ちでないですか？")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUpMode.toggle()
                        errorMessage = nil
                        confirmPassword = ""
                    }
                } label: {
                    Text(isSignUpMode ? "ログインはこちら" : "新規作成はこちら")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(instagramGradient)
                }
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Computed Properties
    private var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    private var canSubmit: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !password.isEmpty && password.count >= 6
        
        if isSignUpMode {
            return emailValid && passwordValid && passwordsMatch && !confirmPassword.isEmpty
        } else {
            return emailValid && passwordValid
        }
    }

    // MARK: - Methods
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
            print("Auth error: \(error)")
            await MainActor.run {
                if isSignUpMode {
                    errorMessage = "登録に失敗しました。別のメールアドレスをお試しください。"
                } else {
                    errorMessage = "ログインに失敗しました。メールアドレスとパスワードをご確認ください。"
                }
            }
        }
    }
    
    private func signInWithApple() async {
        errorMessage = nil
        isAppleLoading = true
        defer { isAppleLoading = false }
        
        do {
            try await authService.signInWithApple()
            await sessionStore.refreshSessionState()
        } catch {
            print("Apple Sign-In error: \(error)")
            if (error as NSError).code != 1001 {
                await MainActor.run {
                    errorMessage = "Appleサインインに失敗しました"
                }
            }
        }
    }
    
    private func signInWithGoogle() async {
        errorMessage = nil
        isGoogleLoading = true
        defer { isGoogleLoading = false }
        
        do {
            try await authService.signInWithGoogle()
            await sessionStore.refreshSessionState()
        } catch {
            print("Google Sign-In error: \(error)")
            if (error as NSError).code != 1 {
                await MainActor.run {
                    errorMessage = "Googleサインインに失敗しました"
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
}
