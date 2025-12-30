import SwiftUI
import AuthenticationServices

struct AuthPromptView: View {
    let feature: String  // "投稿" or "挑戦"
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false
    @State private var errorMessage: String?
    
    private let authService = AuthService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: - Header
                        headerSection
                        
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
                        }
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: AppColors.primary.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Mode Switch
                        modeSwitch
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 70, height: 70)
                
                Image(systemName: feature == "投稿" ? "square.and.pencil" : "lock.open.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            Text("\(feature)するにはログインが必要です")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("アカウントを作成すると、すべての機能を利用できます")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
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
            
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(AppColors.primary)
                    .frame(width: 20)
                
                SecureField("パスワード", text: $password)
            }
            .padding(14)
            .background(AppColors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text(isSignUpMode ? "アカウント作成" : "ログイン")
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
    
    // MARK: - Mode Switch
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            Text(isSignUpMode ? "既にアカウントをお持ちですか？" : "アカウントをお持ちでないですか？")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Button {
                withAnimation {
                    isSignUpMode.toggle()
                    errorMessage = nil
                }
            } label: {
                Text(isSignUpMode ? "ログイン" : "新規登録")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        password.count >= 6
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
            dismiss()
        } catch {
            print("Auth error: \(error)")
            await MainActor.run {
                errorMessage = isSignUpMode
                    ? "登録に失敗しました。別のメールアドレスをお試しください。"
                    : "ログインに失敗しました。メールアドレスとパスワードをご確認ください。"
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
            dismiss()
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
            dismiss()
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
    AuthPromptView(feature: "投稿")
        .environmentObject(SessionStore())
}
