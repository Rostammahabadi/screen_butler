import SwiftUI

struct APIKeyView: View {
    @ObservedObject var openAIService: OpenAIService
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var isTestSuccessful: Bool = false
    @State private var showSkipOption: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenAI API Key Required")
                .font(.headline)
                .padding(.top)
            
            Text("To use the AI rename feature, you need to provide your OpenAI API key. This key will be stored securely on your device only.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            TextField("Enter your OpenAI API key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .autocorrectionDisabled()
                #if os(iOS)
                .autocapitalization(.none)
                #endif
            
            if isTesting {
                ProgressView("Testing API key...")
                    .padding()
            } else if let result = testResult {
                VStack {
                    Text(result)
                        .foregroundColor(isTestSuccessful ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !isTestSuccessful && showSkipOption {
                        Text("You can save the key anyway, but it may not work with OpenAI.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                if showSkipOption && !isTestSuccessful {
                    Button("Save Anyway") {
                        saveKeyAndDismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(isTesting ? "Testing..." : "Test & Save") {
                    testAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isTesting)
            }
            .padding(.bottom)
            
            // Skip option
            Button("Continue in Demo Mode") {
                // Don't save any key, just close the dialog
                isPresented = false
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 350, maxWidth: 450)
        .onAppear {
            // Pre-populate with any existing key
            apiKey = openAIService.apiKey
        }
    }
    
    private func testAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        isTesting = true
        testResult = nil
        showSkipOption = false
        
        openAIService.testAPIKey(apiKey) { isValid, errorMessage in
            isTesting = false
            isTestSuccessful = isValid
            
            if isValid {
                testResult = "✅ API key is valid!"
                saveKeyAndDismiss()
            } else {
                // Show error and option to save anyway
                testResult = "❌ \(errorMessage ?? "Invalid API key")"
                showSkipOption = true
            }
        }
    }
    
    private func saveKeyAndDismiss() {
        // Save the API key
        openAIService.apiKey = apiKey
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
}

#Preview {
    APIKeyView(openAIService: OpenAIService(), isPresented: .constant(true))
} 