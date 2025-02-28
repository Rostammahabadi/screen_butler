import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SignUpViewModel()
    @FocusState private var focusedField: Field?
    @State private var isKeyboardVisible = false
    
    enum Field: Hashable {
        case name
        case email
        case password
        case confirmPassword
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header with back button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Please fill in the details to create your account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    
                    // Form fields
                    VStack(spacing: 20) {
                        CustomTextField(
                            icon: "person",
                            title: "Full Name",
                            hint: "Enter your full name",
                            value: $viewModel.name,
                            errorMessage: viewModel.nameError,
                            isSecure: false
                        )
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .email
                        }
                        
                        CustomTextField(
                            icon: "envelope",
                            title: "Email",
                            hint: "Enter your email address",
                            value: $viewModel.email,
                            errorMessage: viewModel.emailError,
                            isSecure: false
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        
                        CustomTextField(
                            icon: "lock",
                            title: "Password",
                            hint: "Create a strong password",
                            value: $viewModel.password,
                            errorMessage: viewModel.passwordError,
                            isSecure: true,
                            showPassword: $viewModel.isShowingPassword
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                        
                        CustomTextField(
                            icon: "lock.shield",
                            title: "Confirm Password",
                            hint: "Re-enter your password",
                            value: $viewModel.confirmPassword,
                            errorMessage: viewModel.confirmPasswordError,
                            isSecure: true,
                            showPassword: $viewModel.isShowingConfirmPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                            if viewModel.isFormValid {
                                Task {
                                    await viewModel.signUp()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: focusedField) { oldValue, newValue in
                        withAnimation {
                            isKeyboardVisible = newValue != nil
                        }
                    }
                    
                    // Terms and privacy policy
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Toggle(isOn: $viewModel.agreedToTerms) {
                                Text("I agree to the Terms & Privacy Policy")
                                    .font(.footnote)
                            }
                            
                            if !viewModel.termsError.isEmpty {
                                Text(viewModel.termsError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        // Sign up button
                        PrimaryButton(
                            title: "Create Account",
                            isLoading: viewModel.isLoading,
                            action: {
                                Task {
                                    await viewModel.signUp()
                                }
                            },
                            isDisabled: !viewModel.isFormValid
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.bottom, isKeyboardVisible ? 280 : 0)
                .frame(minHeight: geometry.size.height)
            }
            .scrollDisabled(!isKeyboardVisible)
        }
        .background(
            Color.gray.opacity(0.03)
                .edgesIgnoringSafeArea(.all)
        )
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Registration Failed"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
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
        SignUpView()
    }
} 