import SwiftUI

struct ForgotPasswordScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State var viewModel: ForgotPasswordViewModel

    @FocusState private var emailFocused: Bool

    init(viewModel: ForgotPasswordViewModel) {
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
            case .sent:
                successView
            case .idle, .submitting, .error:
                formContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .sensoryFeedback(.success, trigger: viewModel.state == .sent)
        .task { emailFocused = true }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .padding(.top, 8)

            Text("Forgot Password?")
                .font(SvFont.heading)
                .foregroundStyle(.black)
                .padding(.top, 16)

            Text("Please enter your registered email address to recover your password")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 8)

            Text("Email")
                .font(SvFont.label)
                .foregroundStyle(Color(red: 0.239, green: 0.239, blue: 0.239))
                .padding(.top, 28)

            pinkBorderedField(
                placeholder: "Enter email address",
                text: $viewModel.email,
                errorKey: errorKey(for: viewModel.emailError)
            )
            .focused($emailFocused)
            .submitLabel(.send)
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
                isLoading: viewModel.state == .submitting
            ) {
                Task { await viewModel.submit() }
            }
            .padding(.top, 33)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(SvBrandGradient.button)
                    .frame(width: 101, height: 101)
                Image("Check")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.svOnPrimary)
            }
            .accessibilityHidden(true)

            Text("Reset link sent!")
                .font(SvFont.heading)
                .foregroundStyle(Color.svOnBackground)
                .padding(.top, SvSpacing.xxl)

            Text("We've sent a password reset link to\n\(viewModel.email). Please check your\ninbox and follow the link to reset your\npassword.")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, SvSpacing.md)
                .padding(.horizontal, SvSpacing.screenPadding)

            SvPrimaryButton(title: "Back to Login") {
                router.popToRoot()
                router.navigate(to: .login)
            }
            .padding(.horizontal, SvSpacing.screenPadding)
            .padding(.top, SvSpacing.lg)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pink-bordered text field

    private func pinkBorderedField(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        errorKey: LocalizedStringKey?
    ) -> some View {
        HStack(spacing: 8) {
            let styledPrompt = Text(placeholder)
                .foregroundStyle(Color(red: 0.361, green: 0.361, blue: 0.361))
            TextField("", text: text, prompt: styledPrompt)
                .font(.custom("Poppins-Regular", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
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

    private func errorKey(for error: ValidationError?) -> LocalizedStringKey? {
        guard let error else { return nil }
        switch error {
        case .empty:         return "form.error.empty"
        case .invalidFormat: return "auth.error.email_format"
        default:             return "form.error.invalid_format"
        }
    }
}

#Preview("Forgot - Idle") {
    NavigationStack {
        ForgotPasswordScreen(viewModel: .previewInstance())
    }
    .environment(AppRouter())
}

#Preview("Forgot - Submitting") {
    NavigationStack {
        ForgotPasswordScreen(viewModel: .previewInstance(state: .submitting))
    }
    .environment(AppRouter())
}

#Preview("Forgot - Sent") {
    NavigationStack {
        let vm: ForgotPasswordViewModel = {
            let vm = ForgotPasswordViewModel.previewInstance(state: .sent)
            vm.email = "owner@svangur.is"
            return vm
        }()
        ForgotPasswordScreen(viewModel: vm)
    }
    .environment(AppRouter())
}

#Preview("Forgot - Error") {
    NavigationStack {
        ForgotPasswordScreen(viewModel: .previewInstance(state: .error("Network unreachable")))
    }
    .environment(AppRouter())
}
