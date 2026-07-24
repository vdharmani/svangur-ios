import SwiftUI

struct OfferDetailScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var languageService: LanguageService
    @StateObject var viewModel: OfferDetailViewModel

    @State private var showDeleteConfirm = false

    init(viewModel: OfferDetailViewModel) {
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
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let offer):
                content(for: offer)

            case .deleted:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Offer deleted")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    try? await Task.sleep(for: .milliseconds(700))
                    dismiss()
                }

            case .error(let message):
                VStack(spacing: SvSpacing.lg) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(Color.svSecondary)
                    Text(message)
                        .font(SvFont.bodySmall)
                        .foregroundStyle(Color.svSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SvSpacing.screenPadding)
                    SvPrimaryButton(title: "Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .padding(.horizontal, SvSpacing.screenPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Offer Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            router.navigate(to: .editOffer(offerId: viewModel.offerId))
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this offer?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteOffer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .svErrorBanner(viewModel.actionErrorMessage)
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
        .onChange(of: languageService.current) { newValue in
            Task { await viewModel.onLanguageChange(lang: newValue.rawValue) }
        }
    }

    @ViewBuilder
    private func content(for offer: OfferUi) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imageGallery(urls: offer.imageUrls)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(offer.title)
                            .font(.title2.bold())
                        Spacer()
                        Text(offer.discountBadgeText)
                            .font(SvFont.label)
                            .foregroundStyle(Color.svOnPrimary)
                            .padding(.horizontal, SvSpacing.sm + 2)
                            .padding(.vertical, SvSpacing.xs + 1)
                            .background(Color.svPrimary, in: Capsule())
                    }

                    Text(offer.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Divider()

                    DetailRow(icon: "tag", label: "Category", value: offer.categoryDisplayText)
                    DetailRow(icon: "calendar", label: "Valid days", value: offer.validDaysText)
                    DetailRow(icon: "clock", label: "Valid hours", value: offer.validTimeText)
                    DetailRow(
                        icon: "circle.fill",
                        label: "Status",
                        value: (offer.status?.rawValue ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized,
                        valueColor: offer.isActive ? .green : .orange
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private func imageGallery(urls: [URL]) -> some View {
        if urls.isEmpty {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "fork.knife")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 240)
        } else {
            TabView {
                ForEach(urls, id: \.self) { url in
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .tabViewStyle(.page)
            .frame(height: 240)
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
        .font(.subheadline)
    }
}

// MARK: - Previews

#Preview("Detail - Loaded") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(
            state: .loaded(MockOfferRepository.seed[0].toUi(for: .english))
        ))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}

#Preview("Detail - Loading") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(state: .loading))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}

#Preview("Detail - Error") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(state: .error("Not found")))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}
