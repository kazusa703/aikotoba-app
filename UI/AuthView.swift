import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
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
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Logo Section
                logoSection
                
                Spacer().frame(height: 40)
                
                // MARK: - Input Fields
                inputSection
                
                Spacer().frame(height: 20)
                
                // MARK: - Submit Button
                submitButton
                
                Spacer().frame(height: 24)
                
                // MARK: - Divider
                dividerSection
                
                Spacer()
                
                // MARK: - Bottom Switch
                bottomSwitch
            }
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(instagramGradient)
            }
            
            // App Name
            Text("aikotoba")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .italic()
            
            // Tagline
            Text("秘密の合言葉で繋がる")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // Email Field
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
            
            // Password Field
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("パスワード", text: $password)
            }
            .padding(14)
            .background(subtleGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGray, lineWidth: 1)
            )
            
            // Error Message
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
    
    // MARK: - Bottom Switch
    private var bottomSwitch: some View {
        VStack(spacing: 0) {
            Divider()
            
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
            .padding(.vertical, 20)
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
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
}
