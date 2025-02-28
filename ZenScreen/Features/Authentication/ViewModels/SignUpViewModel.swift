import Foundation
import SwiftUI

class SignUpViewModel: ObservableObject {
    // Form fields
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var agreedToTerms: Bool = false
    
    // UI state
    @Published var isLoading: Bool = false
    @Published var isShowingPassword: Bool = false
    @Published var isShowingConfirmPassword: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var isRegistrationSuccessful: Bool = false
    
    // Validation errors
    @Published var nameError: String = ""
    @Published var emailError: String = ""
    @Published var passwordError: String = ""
    @Published var confirmPasswordError: String = ""
    @Published var termsError: String = ""
    
    // Computed properties for validation
    var isNameValid: Bool {
        if name.isEmpty {
            nameError = "Name is required"
            return false
        }
        
        if name.count < 2 {
            nameError = "Name must be at least 2 characters"
            return false
        }
        
        nameError = ""
        return true
    }
    
    var isEmailValid: Bool {
        if email.isEmpty {
            emailError = "Email is required"
            return false
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            emailError = "Please enter a valid email address"
            return false
        }
        
        emailError = ""
        return true
    }
    
    var isPasswordValid: Bool {
        if password.isEmpty {
            passwordError = "Password is required"
            return false
        }
        
        if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
            return false
        }
        
        // Check for at least one uppercase letter
        let uppercaseRegex = ".*[A-Z]+.*"
        let uppercasePredicate = NSPredicate(format: "SELF MATCHES %@", uppercaseRegex)
        
        // Check for at least one digit
        let digitRegex = ".*[0-9]+.*"
        let digitPredicate = NSPredicate(format: "SELF MATCHES %@", digitRegex)
        
        if !uppercasePredicate.evaluate(with: password) {
            passwordError = "Password must contain at least one uppercase letter"
            return false
        }
        
        if !digitPredicate.evaluate(with: password) {
            passwordError = "Password must contain at least one number"
            return false
        }
        
        passwordError = ""
        return true
    }
    
    var isConfirmPasswordValid: Bool {
        if confirmPassword.isEmpty {
            confirmPasswordError = "Please confirm your password"
            return false
        }
        
        if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
            return false
        }
        
        confirmPasswordError = ""
        return true
    }
    
    var isTermsAgreed: Bool {
        if !agreedToTerms {
            termsError = "You must agree to the terms and privacy policy"
            return false
        }
        
        termsError = ""
        return true
    }
    
    var isFormValid: Bool {
        return isNameValid && isEmailValid && isPasswordValid && isConfirmPasswordValid && isTermsAgreed
    }
    
    func signUp() async {
        // Reset any previous errors
        DispatchQueue.main.async {
            self.validateAll()
            
            guard self.isFormValid else {
                return
            }
            
            self.isLoading = true
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Mock signup logic - in a real app, this would call an authentication service
        let success = true // Simulate successful registration
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                self.isRegistrationSuccessful = true
                // In a real app, you might navigate to a verification screen or login
            } else {
                self.showAlert = true
                self.alertMessage = "Registration failed. Please try again later."
            }
        }
    }
    
    private func validateAll() {
        // Trigger all validations
        _ = isNameValid
        _ = isEmailValid
        _ = isPasswordValid
        _ = isConfirmPasswordValid
        _ = isTermsAgreed
    }
    
    func resetForm() {
        name = ""
        email = ""
        password = ""
        confirmPassword = ""
        agreedToTerms = false
        isShowingPassword = false
        isShowingConfirmPassword = false
        nameError = ""
        emailError = ""
        passwordError = ""
        confirmPasswordError = ""
        termsError = ""
    }
} 