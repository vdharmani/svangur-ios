import SwiftUI

struct ChangePasswordScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ChangePasswordViewModel

    @FocusState private var focusedField: Field?
    @State private var revealCurrent = false
    @State private var revealNew = false
    @State private var revealConfirm = false
    private enum Field: Hashable { case currentPassword, newPassword, confirmPassword }

    init(viewModel: ChangePasswordViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
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
        .svSuccessFeedback(trigger: viewModel.state == .success)
        .task { focusedField = .currentPassword }
        .svErrorBanner(changePasswordErrorMessage)
    }

    /// Server/API errors (e.g. wrong current password) surface as a banner over the top of the
    /// screen — distinct from per-field validation errors, which stay inline under each field.
    private var changePasswordErrorMessage: String? {
        guard case .error(let message) = viewModel.state else { return nil }
        return message
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SvSpacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.svOnBackground)
                        .frame(width: 15, height: 44, alignment: .leading)
                }
                .accessibilityLabel("Back")

                Text("Change Password")
                    .font(SvFont.titleSmall)
                    .foregroundStyle(Color.svOnBackground)

                Spacer()
            }
            .padding(.top, 8)

            Text("Current Password")
                .font(SvFont.label)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 28)

            pinkSecureField(
                placeholder: "Enter current password",
                text: $viewModel.currentPassword,
                reveal: $revealCurrent
            )
            .focused($focusedField, equals: .currentPassword)
            .submitLabel(.next)
            .onSubmit { focusedField = .newPassword }
            .padding(.top, 16)

            if let key = errorKey(for: viewModel.validation.currentPassword, emptyMessage: "Please enter current password") {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
                    .padding(.top, 6)
            }

            Text("New Password")
                .font(SvFont.label)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 20)

            pinkSecureField(
                placeholder: "Enter new password",
                text: $viewModel.newPassword,
                reveal: $revealNew
            )
            .focused($focusedField, equals: .newPassword)
            .submitLabel(.next)
            .onSubmit { focusedField = .confirmPassword }
            .padding(.top, 16)

            if let key = errorKey(for: viewModel.validation.newPassword, emptyMessage: "Please enter new password") {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
                    .padding(.top, 6)
            }

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

            if let key = errorKey(for: viewModel.validation.confirmPassword, emptyMessage: "Please enter confirm password.") {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
                    .padding(.top, 6)
            }

            SvPrimaryButton(
                title: "Update Password",
                isLoading: viewModel.state == .submitting
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
                .foregroundColor(Color(red: 0.361, green: 0.361, blue: 0.361))
            Group {
                if reveal.wrappedValue {
                    TextField("", text: text, prompt: styledPrompt)
                } else {
                    SecureField("", text: text, prompt: styledPrompt)
                }
            }
            .font(.custom("Poppins-Regular", size: 15, relativeTo: .subheadline))
            .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067))
            .textContentType(.password)
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
                Text("Your password has been changed successfully.")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SvSpacing.screenPadding)
            }
            SvPrimaryButton(title: "Done") {
                dismiss()
            }
            .padding(.horizontal, SvSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorKey(for error: ValidationError?, emptyMessage: LocalizedStringKey) -> LocalizedStringKey? {
        guard let error else { return nil }
        switch error {
        case .empty:           return emptyMessage
        case .tooShort(let m): return "Must be at least \(m) characters"
        case .tooLong(let m):  return "Must be \(m) characters or fewer"
        case .invalidFormat:   return "Please enter a valid value"
        case .custom(let key): return LocalizedStringKey(key)
        }
    }
}

#Preview("Change Password - Idle") {
    NavigationStack {
        ChangePasswordScreen(viewModel: .previewInstance())
    }
}

#Preview("Change Password - Submitting") {
    NavigationStack {
        ChangePasswordScreen(viewModel: .previewInstance(state: .submitting))
    }
}

#Preview("Change Password - Success") {
    NavigationStack {
        ChangePasswordScreen(viewModel: .previewInstance(state: .success))
    }
}

#Preview("Change Password - Error") {
    NavigationStack {
        ChangePasswordScreen(viewModel: .previewInstance(state: .error("Current password is incorrect")))
    }
}
