import Foundation
import Combine

class LoginViewModel: ObservableObject {
    // Published properties for form inputs
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isShowingPassword: Bool = false
    
    // Published properties for validation and state
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    // Validation state
    var isFormValid: Bool {
        return isEmailValid && isPasswordValid
    }
    
    private var isEmailValid: Bool {
        return !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    private var isPasswordValid: Bool {
        return !password.isEmpty && password.count >= 6
    }
    
    // Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupValidation()
    }
    
    private func setupValidation() {
        // Email validation
        $email
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { email in
                if email.isEmpty {
                    return "Email is required"
                } else if !email.contains("@") || !email.contains(".") {
                    return "Please enter a valid email"
                } else {
                    return nil
                }
            }
            .assign(to: \.emailError, on: self)
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { password in
                if password.isEmpty {
                    return "Password is required"
                } else if password.count < 6 {
                    return "Password must be at least 6 characters"
                } else {
                    return nil
                }
            }
            .assign(to: \.passwordError, on: self)
            .store(in: &cancellables)
    }
    
    func login() async {
        isLoading = true
        
        // In a real app, you would make an API call here
        // This is a simulated network delay
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        
        await MainActor.run {
            if email == "test@example.com" && password == "password123" {
                self.isAuthenticated = true
            } else {
                self.showAlert = true
                self.alertMessage = "Invalid email or password. Please try again."
            }
            self.isLoading = false
        }
    }
    
    func resetForm() {
        email = ""
        password = ""
        isShowingPassword = false
    }
} 