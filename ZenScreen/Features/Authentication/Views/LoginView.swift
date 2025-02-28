import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: LoginViewModel
    @State private var isKeyboardVisible = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email
        case password
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 36) {
                    // Logo and welcome text
                    VStack(spacing: 16) {
                        Image(systemName: "apps.iphone")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .foregroundColor(.blue)
                            .padding(.vertical, 12)
                            .shadow(color: .blue.opacity(0.2), radius: 10, x: 0, y: 4)
                        
                        Text("Welcome to ScreenButler")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, max(geometry.size.height * 0.05, 20))
                    
                    // Form fields
                    VStack(spacing: 24) {
                        CustomTextField(
                            icon: "envelope",
                            title: "Email",
                            hint: "Enter your email",
                            value: $viewModel.email,
                            errorMessage: viewModel.emailError,
                            isSecure: false
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .onChange(of: focusedField) { oldValue, newValue in
                            withAnimation {
                                isKeyboardVisible = newValue != nil
                            }
                        }
                        
                        CustomTextField(
                            icon: "lock",
                            title: "Password",
                            hint: "Enter your password",
                            value: $viewModel.password,
                            errorMessage: viewModel.passwordError,
                            isSecure: true,
                            showPassword: $viewModel.isShowingPassword
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                            if viewModel.isFormValid {
                                Task {
                                    await viewModel.login()
                                }
                            }
                        }
                        
                        // Forgot password link
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                // Handle forgot password
                            }
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.top, -8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Login button and sign up
                    VStack(spacing: 24) {
                        PrimaryButton(
                            title: "Sign In",
                            isLoading: viewModel.isLoading,
                            action: {
                                Task {
                                    await viewModel.login()
                                }
                            },
                            isDisabled: !viewModel.isFormValid
                        )
                        .padding(.top, 12)
                        
                        // Don't have an account
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            
                            NavigationLink(destination: SignUpView()) {
                                Text("Sign Up")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.bottom, isKeyboardVisible ? 280 : 0)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 24)
            }
            .scrollDisabled(!isKeyboardVisible)
        }
        .background(
            Color.gray.opacity(0.03)
                .edgesIgnoringSafeArea(.all)
        )
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Login Failed"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LoginView()
            .environmentObject(LoginViewModel())
    }
    #if os(iOS)
    .navigationViewStyle(StackNavigationViewStyle())
    #endif
} 