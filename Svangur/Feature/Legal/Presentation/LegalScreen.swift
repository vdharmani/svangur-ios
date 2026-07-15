import SwiftUI

struct LegalScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageService: LanguageService
    @StateObject var viewModel: LegalViewModel

    init(viewModel: LegalViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            switch viewModel.state {
            case .idle, .loading:
                loadingState
            case .loaded(let html):
                SvHTMLWebView(html: html, baseURL: nil)
            case .error(let message):
                errorState(message)
            }
        }
        .background(Color.svBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
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
                Task { await viewModel.refresh(lang: languageService.current.rawValue) }
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
