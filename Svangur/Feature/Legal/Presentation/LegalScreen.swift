import SwiftUI

struct LegalScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageService: LanguageService
    @StateObject var viewModel: LegalViewModel

    /// Local, screen-only language selection — seeded from the app's current language on
    /// appear so the document opens in the language the user is already browsing in, but never
    /// written back to `languageService`. Switching this pill only re-fetches the document
    /// below; it must never change the app's global language or affect any other screen (Home's
    /// own language toggle is untouched and works entirely independently of this).
    @State private var selectedLanguage: AppLanguage = .english

    init(viewModel: LegalViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            languageToggle

            switch viewModel.state {
            case .idle, .loading:
                loadingState
            case .loaded(let html):
                // The backend bakes its own `.lang-switch` anchor links into this HTML, but
                // they're dead in a WKWebView loaded via `loadHTMLString(_:baseURL: nil)` — hide
                // them so `languageToggle` above is the only (functional) language control shown.
                SvHTMLWebView(html: html + "<style>.lang-switch{display:none}</style>", baseURL: nil)
            case .error(let message):
                errorState(message)
            }
        }
        .background(Color.svBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            selectedLanguage = languageService.current
            await viewModel.onAppear(lang: selectedLanguage.rawValue)
        }
        .onChange(of: selectedLanguage) { newValue in
            Task { await viewModel.refresh(lang: newValue.rawValue) }
        }
    }

    // MARK: - Language toggle

    private var languageToggle: some View {
        HStack(spacing: SvSpacing.sm) {
            languagePill(title: "English", isSelected: selectedLanguage == .english) {
                setLanguage(.english)
            }
            languagePill(title: "Íslenska", isSelected: selectedLanguage == .icelandic) {
                setLanguage(.icelandic)
            }
            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.md)
    }

    private func languagePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(SvFont.captionStrong)
                .foregroundStyle(isSelected ? Color.svOnPrimary : Color.svOnBackground)
                .padding(.horizontal, SvSpacing.lg)
                .padding(.vertical, SvSpacing.sm)
                .background(
                    Capsule().fill(isSelected ? Color.svPrimary : Color.svOnPrimary)
                )
                .overlay(
                    Capsule().stroke(Color.svDivider, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func setLanguage(_ language: AppLanguage) {
        guard selectedLanguage != language else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedLanguage = language
        }
    }

    private var header: some View {
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

            Text(viewModel.documentType.title)
                .font(SvFont.titleSmall)
                .foregroundStyle(Color.svOnBackground)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, 8)
    }

    private var loadingState: some View {
        VStack {
            ProgressView()
            Spacer()
        }
        .padding(.top, SvSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: SvSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.svSecondary)
            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            SvPrimaryButton(title: "Retry") {
                Task { await viewModel.refresh(lang: selectedLanguage.rawValue) }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Legal - Loading") {
    NavigationStack {
        LegalScreen(viewModel: .previewInstance(state: .loading))
    }
    .environmentObject(LanguageService())
}

#Preview("Legal - Loaded") {
    NavigationStack {
        LegalScreen(viewModel: .previewInstance(documentType: .terms, state: .loaded(html: "<h1>Terms</h1><p>Preview.</p>")))
    }
    .environmentObject(LanguageService())
}

#Preview("Legal - Error") {
    NavigationStack {
        LegalScreen(viewModel: .previewInstance(state: .error("Something went wrong")))
    }
    .environmentObject(LanguageService())
}
