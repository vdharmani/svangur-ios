import SwiftUI

struct SvTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .never
    var errorKey: LocalizedStringKey?

    @FocusState private var isFocused: Bool
    @State private var revealPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: SvSpacing.xs) {
            HStack(spacing: SvSpacing.sm) {
                Group {
                    if isSecure && !revealPassword {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .focused($isFocused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(isSecure || keyboard == .emailAddress)
                .font(SvFont.body)
                .foregroundStyle(Color.svOnBackground)

                if isSecure {
                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                            .foregroundStyle(Color.svSecondary)
                    }
                    .accessibilityLabel(revealPassword ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, SvSpacing.lg)
            .frame(height: SvSpacing.inputHeight)
            .background(
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .fill(Color.svFieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .stroke(strokeColor, lineWidth: errorKey != nil || isFocused ? 1.5 : 0)
            )

            if let errorKey {
                Text(errorKey)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }
        }
    }

    private var strokeColor: Color {
        if errorKey != nil { return .svError }
        if isFocused      { return .svPrimary }
        return .clear
    }
}

#Preview("Fields") {
    SvTextFieldPreviewContainer()
}

// `@Previewable` (Swift 5.10/Xcode 16 preview macro) is iOS 17+ only — with this project's
// iOS 16 deployment target, `#Preview` bodies that need local `@State` fall back to a small
// private wrapper `View` instead.
private struct SvTextFieldPreviewContainer: View {
    @State private var email = ""
    @State private var password = "secret"

    var body: some View {
        VStack(spacing: SvSpacing.formFieldSpacing) {
            SvTextField(
                placeholder: "Email",
                text: $email,
                keyboard: .emailAddress,
                contentType: .emailAddress
            )
            SvTextField(
                placeholder: "Password",
                text: $password,
                isSecure: true,
                contentType: .password
            )
            SvTextField(
                placeholder: "Email",
                text: .constant("not-an-email"),
                keyboard: .emailAddress,
                errorKey: "Invalid email"
            )
        }
        .padding(SvSpacing.screenPadding)
        .background(Color.svBackground)
    }
}
