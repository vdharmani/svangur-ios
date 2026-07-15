import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: UserSession
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: LoginViewModel
    @State private var revealPassword = false

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, password }

    init(viewModel: LoginViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // White screen background
            Color.svBackground.ignoresSafeArea()

            // Pink gradient header with concave-up curved bottom edge
            CurvedHeaderShape()
                .fill(SvLoginHeaderGradient.fill)
                .frame(height: 287)
                .shadow(color: .black.opacity(0.078), radius: 11, x: 0, y: -6)
                .ignoresSafeArea(edges: .top)

            // Page content — respects the top safe area, same as ForgotPasswordScreen,
            // so the back button lands in the same screen position on both screens.
            VStack(spacing: 25) {
                header
                form
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .svErrorBanner(loginErrorMessage)
        .onChange(of: viewModel.effect) { effect in
            guard case .loggedIn(let token) = effect else { return }
            session.adopt(token)
            viewModel.consumeEffect()
            router.popToRoot()
        }
        .task { await viewModel.onAppear() }
    }

    // MARK: - Header (back button + logo over the curved pink area)
    
    private var header: some View {
        // Logo — vertically centered in the pink area, same position as before.
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            Image(.svangurWordmark)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 211, height: 58)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 270)
        .overlay(alignment: .topLeading) {
            // Back button — pinned independently to the top, same position as
            // ForgotPasswordScreen's back button (screenPadding leading, 8pt top,
            // both measured from the safe area) — not affected by the logo's centering.
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
            .padding(.leading, SvSpacing.screenPadding)
            .padding(.top, 8)
        }
    }

    /// Server/API errors (e.g. a failed login attempt) surface as a banner over the pink
    /// header — distinct from per-field validation errors, which stay inline under each field.
    private var loginErrorMessage: String? {
        guard case .error(let message) = viewModel.loadState else { return nil }
        return message
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Email")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)
                .padding(.top, 24)

            pinkBorderedField(
                placeholder: "Enter email address",
                text: $viewModel.email,
                isSecure: false,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                errorKey: errorKey(for: viewModel.validation.email)
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .padding(.top, 16)

            Text("Password")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)
                .padding(.top, 22)

            pinkBorderedField(
                placeholder: "Enter password",
                text: $viewModel.password,
                isSecure: true,
                contentType: .password,
                keyboard: .default,
                errorKey: errorKey(for: viewModel.validation.password)
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { Task { await viewModel.submit() } }
            .padding(.top, 16)

            HStack(spacing: 0) {
                Button {
                    viewModel.rememberMe.toggle()
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color(red: 0.58, green: 0.58, blue: 0.58), lineWidth: 1.2)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(viewModel.rememberMe ? Color.svPrimary : Color.clear)
                            )
                            .frame(width: 12, height: 12)
                            .overlay {
                                if viewModel.rememberMe {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text("Remember me")
                            .font(.custom("Poppins-Regular", size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color(red: 0.118, green: 0.118, blue: 0.118))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    router.navigate(to: .forgotPassword)
                } label: {
                    Text("Forgot Password?")
                        .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.svPrimary)
                }
            }
            .padding(.top, 17)

            SvPrimaryButton(
                title: "Login",
                isLoading: viewModel.loadState == .submitting
            ) {
                Task { await viewModel.submit() }
            }
            .padding(.top, 33)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Pink-bordered text field

    private func pinkBorderedField(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        isSecure: Bool,
        contentType: UITextContentType?,
        keyboard: UIKeyboardType,
        errorKey: LocalizedStringKey?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Group {
                    let styledPrompt = Text(placeholder)
                        .foregroundColor(Color(red: 0.361, green: 0.361, blue: 0.361))
                    if isSecure && !revealPassword {
                        SecureField("", text: text, prompt: styledPrompt)
                    } else {
                        TextField("", text: text, prompt: styledPrompt)
                    }
                }
                .font(.custom("Poppins-Regular", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067))
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

                if isSecure {
                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye" : "eye.slash")
                            .foregroundStyle(Color(red: 0.514, green: 0.514, blue: 0.514))
                    }
                    .accessibilityLabel(revealPassword ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 55)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.svPrimary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(errorKey == nil ? Color.svPrimary : Color.svError, lineWidth: 1)
            )

            if let errorKey {
                Text(errorKey)
                    .font(.caption)
                    .foregroundStyle(Color.svError)
            }
        }
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

// MARK: - Curved header shape (pink area with concave-up bottom)

private struct CurvedHeaderShape: Shape {
    /// How far the middle of the curve dips up from the side baseline.
    var curveDepth: CGFloat = 53

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        // Right edge — pink extends all the way to maxY (deepest)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Curve up in the middle to (midX, maxY - curveDepth) and back down
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - curveDepth * 2)
        )
        path.closeSubpath()
        return path
    }
}

private enum SvLoginHeaderGradient {
    // #FAA5B6 at top → #F06285 at bottom, matching Figma design
    static let fill = LinearGradient(
        colors: [.svPrimaryGradientStart, .svPrimaryGradientEnd],
        startPoint: .top,
        endPoint: .bottom
    )
}

#Preview("Login - Empty") {
    NavigationStack {
        LoginScreen(viewModel: .previewInstance())
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
}

#Preview("Login - Submitting") {
    NavigationStack {
        LoginScreen(viewModel: .previewInstance(loadState: .submitting))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
}

#Preview("Login - Error") {
    NavigationStack {
        LoginScreen(viewModel: .previewInstance(loadState: .error("Invalid email or password")))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
}
