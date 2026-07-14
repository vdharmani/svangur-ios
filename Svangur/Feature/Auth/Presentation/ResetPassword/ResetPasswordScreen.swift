import SwiftUI

struct ResetPasswordScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State var viewModel: ResetPasswordViewModel

    @FocusState private var focusedField: Field?
    @State private var revealNew = false
    @State private var revealConfirm = false
    private enum Field: Hashable { case newPassword, confirmPassword }

    init(viewModel: ResetPasswordViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    @ViewBuilder
    private func compactLayout() -> some View {
        ZStack {
            Color.svBackground.ignoresSafeArea()

            switch viewModel.state {
            case .success:
                successView
            case .idle, .submitting, .error:
                form
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: viewModel.state == .success)
        .task { focusedField = .newPassword }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            .padding(.top, 8)

            Text("Reset Password")
                .font(SvFont.heading)
                .foregroundStyle(.black)
                .padding(.top, 16)

            Text("Create a new password for your account. Make sure it's strong and secure.")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 8)

            Text("New Password")
                .font(SvFont.label)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 28)

            pinkSecureField(
                placeholder: "Enter new password",
                text: $viewModel.newPassword,
                reveal: $revealNew
            )
            .focused($focusedField, equals: .newPassword)
            .submitLabel(.next)
            .onSubmit { focusedField = .confirmPassword }
            .padding(.top, 16)

            Text("Confirm Password")
                .font(SvFont.label)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 20)

            pinkSecureField(
                placeholder: "Enter password again",
                text: $viewModel.confirmPassword,
                reveal: $revealConfirm
            )
            .focused($focusedField, equals: .confirmPassword)
            .submitLabel(.go)
            .onSubmit { Task { await viewModel.submit() } }
            .padding(.top, 16)

            if case .error(let message) = viewModel.state {
                Text(message)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
                    .padding(.top, 8)
            }

            SvPrimaryButton(
                title: "Submit",
                isLoading: viewModel.state == .submitting,
                isEnabled: viewModel.canSubmit
            ) {
                Task { await viewModel.submit() }
            }
            .padding(.top, 33)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Pink-bordered secure field

    private func pinkSecureField(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        reveal: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            let styledPrompt = Text(placeholder)
                .foregroundStyle(Color(red: 0.361, green: 0.361, blue: 0.361))
            Group {
                if reveal.wrappedValue {
                    TextField("", text: text, prompt: styledPrompt)
                } else {
                    SecureField("", text: text, prompt: styledPrompt)
                }
            }
            .font(.custom("Poppins-Regular", size: 15, relativeTo: .subheadline))
            .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067))
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                reveal.wrappedValue.toggle()
            } label: {
                Image(systemName: reveal.wrappedValue ? "eye" : "eye.slash")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.svSecondary)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(reveal.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 18)
        .frame(height: SvSpacing.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.svPrimary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .stroke(Color.svPrimary, lineWidth: 1)
        )
    }

    private var successView: some View {
        VStack(spacing: SvSpacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.svPrimary.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.svPrimary)
            }
            VStack(spacing: SvSpacing.sm) {
                Text("Password updated")
                    .font(SvFont.heading)
                    .foregroundStyle(Color.svOnBackground)
                Text("Sign in with your new password to continue.")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SvSpacing.screenPadding)
            }
            SvPrimaryButton(title: "Sign In") {
                router.popToRoot()
                router.navigate(to: .login)
            }
            .padding(.horizontal, SvSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorKey(for error: ValidationError?) -> LocalizedStringKey? {
        guard let error else { return nil }
        switch error {
        case .empty:           return "This field is required"
        case .tooShort(let m): return "Must be at least \(m) characters"
        case .tooLong(let m):  return "Must be \(m) characters or fewer"
        case .invalidFormat:   return "Please enter a valid value"
        case .custom(let key): return LocalizedStringKey(key)
        }
    }
}

#Preview("Reset - Idle") {
    NavigationStack {
        ResetPasswordScreen(viewModel: .previewInstance())
    }
    .environment(AppRouter())
}

#Preview("Reset - Submitting") {
    NavigationStack {
        ResetPasswordScreen(viewModel: .previewInstance(state: .submitting))
    }
    .environment(AppRouter())
}

#Preview("Reset - Success") {
    NavigationStack {
        ResetPasswordScreen(viewModel: .previewInstance(state: .success))
    }
    .environment(AppRouter())
}

#Preview("Reset - Error") {
    NavigationStack {
        ResetPasswordScreen(viewModel: .previewInstance(state: .error("Token expired")))
    }
    .environment(AppRouter())
}
