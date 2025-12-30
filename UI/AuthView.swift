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

    var body: some View {
        ZStack {
            // Background
            AppColors.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    // MARK: - Logo Section
                    logoSection
                    
                    Spacer().frame(height: 32)
                    
                    // MARK: - Mode Title
                    modeTitle
                    
                    Spacer().frame(height: 24)
                    
                    // MARK: - Card Container
                    VStack(spacing: 20) {
                        // Input Fields
                        inputSection
                        
                        // Submit Button
                        submitButton
                        
                        // Divider
                        dividerSection
                        
                        // Social Login
                        socialLoginSection
                        
                        // Guest Mode
                        guestModeButton
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: AppColors.primary.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Spacer().frame(height: 24)
                    
                    // MARK: - Bottom Switch
                    bottomSwitch
                    
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Lock Icon with Circle
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 90, height: 90)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text("aikotoba")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            
            Text("秘密の合言葉で繋がる")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Mode Title
    private var modeTitle: some View {
        VStack(spacing: 8) {
            Text(isSignUpMode ? "アカウント作成" : "ログイン")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(isSignUpMode ? "メールアドレスで新しいアカウントを作成" : "既存のアカウントでログイン")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // Email
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(AppColors.primary)
                    .frame(width: 20)
                
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(14)
            .background(AppColors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            
            // Password
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(AppColors.primary)
                    .frame(width: 20)
                
                SecureField(isSignUpMode ? "パスワード（6文字以上）" : "パスワード", text: $password)
            }
            .padding(14)
            .background(AppColors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            
            // Confirm Password (Sign Up only)
            if isSignUpMode {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(AppColors.primary)
                        .frame(width: 20)
                    
                    SecureField("パスワード（再入力）", text: $confirmPassword)
                }
                .padding(14)
                .background(AppColors.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(passwordsMatch ? AppColors.border : AppColors.error.opacity(0.5), lineWidth: 1)
                )
                
                if !confirmPassword.isEmpty && !passwordsMatch {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                        Text("パスワードが一致しません")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Error Message
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundColor(AppColors.error)
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
            .background(canSubmit ? AppColors.primaryGradient : AppColors.disabledGradient)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSubmit || isLoading)
    }
    
    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            
            Text("または")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(AppColors.border)
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
                .cornerRadius(12)
            }
            .disabled(isAppleLoading || isGoogleLoading)
            
            // Google Sign-In
            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: 8) {
                    if isGoogleLoading {
                        ProgressView()
                            .tint(AppColors.textPrimary)
                    } else {
                        GoogleLogoView()
                        Text("Googleで続ける")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
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
            .background(AppColors.background)
            .foregroundColor(AppColors.textSecondary)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Bottom Switch
    private var bottomSwitch: some View {
        HStack(spacing: 4) {
            Text(isSignUpMode ? "既にアカウントをお持ちですか？" : "アカウントをお持ちでないですか？")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
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
                    .foregroundColor(AppColors.primary)
            }
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
