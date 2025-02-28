import SwiftUI

struct CustomTextField: View {
    var icon: String
    var title: String
    var hint: String
    var value: Binding<String>
    var errorMessage: String?
    var isSecure: Bool = false
    var showPassword: Binding<Bool>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // Text field container
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20)
                
                // Text field
                ZStack(alignment: .leading) {
                    if value.wrappedValue.isEmpty {
                        Text(hint)
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    
                    if isSecure && !(showPassword?.wrappedValue ?? false) {
                        SecureField("", text: value)
                            .disableAutocorrection(true)
                    } else {
                        TextField("", text: value)
                            .disableAutocorrection(true)
                    }
                }
                
                // Show/hide password button
                if isSecure {
                    Button {
                        showPassword?.wrappedValue.toggle()
                    } label: {
                        Image(systemName: showPassword?.wrappedValue ?? false ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
            
            // Error message
            if let errorMessage = errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
} 