import SwiftUI

struct PrimaryButton: View {
    var title: String
    var isLoading: Bool
    var action: () -> Void
    var isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Button background and label
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(isDisabled ? 0.6 : 1.0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    .opacity(isLoading ? 0.8 : 1)
                
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.0)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(
            title: "Sign In",
            isLoading: false,
            action: {},
            isDisabled: false
        )
        
        PrimaryButton(
            title: "Sign In",
            isLoading: true,
            action: {},
            isDisabled: false
        )
        
        PrimaryButton(
            title: "Sign In",
            isLoading: false,
            action: {},
            isDisabled: true
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .previewLayout(.sizeThatFits)
} 