import SwiftUI
import AuthenticationServices

struct AuthPromptView: View {
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
    
    let feature: String // "投稿" or "挑戦"
    
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    headerSection
                    
                    // MARK: - Social Login Buttons
                    socialLoginSection
                    
                    // MARK: - Divider
                    dividerSection
                    
                    // MARK: - Input Fields
                    inputSection
                    
                    // MARK: - Submit Button
                    submitButton
                    
                    // MARK: - Toggle Mode
                    toggleModeButton
                }
                .padding(24)
            }
            .background(Color.white)
            .navigationTitle(isSignUpMode ? "新規登録" : "ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Image(systemName: feature == "投稿" ? "plus.circle.fill" : "lock.open.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(instagramGradient)
            }
            
            Text("\(feature)するにはログインが必要です")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("アカウントを作成して、すべての機能をお楽しみください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
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
                        Text("Appleでサインイン")
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
                        Text("Googleでサインイン")
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
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
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
            
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("パスワード（6文字以上）", text: $password)
            }
            .padding(14)
            .background(subtleGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGray, lineWidth: 1)
            )
            
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
                    Text(isSignUpMode ? "新規登録" : "ログイン")
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
    
    // MARK: - Toggle Mode Button
    private var toggleModeButton: some View {
        HStack(spacing: 4) {
            Text(isSignUpMode ? "アカウントをお持ちですか？" : "アカウントをお持ちでないですか？")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUpMode.toggle()
                    errorMessage = nil
                }
            } label: {
                Text(isSignUpMode ? "ログイン" : "登録する")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(instagramGradient)
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
            await MainActor.run {
                errorMessage = "Googleサインインに失敗しました"
            }
        }
    }
}

#Preview {
    AuthPromptView(feature: "投稿")
        .environmentObject(SessionStore())
}
