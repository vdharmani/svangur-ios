import SwiftUI

struct OfferPreviewScreen: View {
    let draft: OfferDraft
    /// Resolved display name for `draft.categoryId` — passed in by the caller (`AddOfferScreen`,
    /// which has access to the real `[DealCategory]` list) rather than looked up here, so this
    /// screen doesn't need a `DealRepository` dependency of its own.
    var categoryName: String? = nil
    let isSaving: Bool
    let onConfirm: () -> Void
    let onBack: () -> Void
    var restaurantName: String = "Bella Italia"
    var description = "Short and clear description of the offer"

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            ScrollView {
                offerCard
                    .padding(.horizontal, SvSpacing.screenPadding)
                    .padding(.top, SvSpacing.md)
                    .padding(.bottom, SvSpacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.svBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    // MARK: - Header

    private var customHeader: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            HStack(spacing: SvSpacing.sm) {
                Button(action: onBack) {
                    Image("ic_Back")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.svOnBackground)
                        .frame(width: 15, height: 14, alignment: .leading)
                }
                .accessibilityLabel("Back")

                Text("Preview Offer")
                    .font(SvFont.title)
                    .foregroundStyle(Color.svLabel)
                Spacer()
            }
            .padding(.horizontal, SvSpacing.screenPadding)

            Text("This is how your offer will appear to customers")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.bottom, SvSpacing.md)
        }
    }

    // MARK: - Card

    private var offerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                heroImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipped()

                if let discountBadgeText {
                    Text(discountBadgeText)
                        .font(SvFont.captionStrong)
                        .foregroundStyle(Color.svOnPrimary)
                        .padding(.horizontal, SvSpacing.md)
                        .padding(.vertical, SvSpacing.xs + 1)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.svPrimaryGradientStart, Color.svPrimaryGradientEnd],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .padding(SvSpacing.md)
                }
            }

            // --- Content Section ---
            VStack(alignment: .leading, spacing: SvSpacing.sm) {
                Text(restaurantName)
                    .font(SvFont.title)
                    .foregroundStyle(Color.svLabel)

                Text(metaLine)
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)

                Spacer().frame(height: SvSpacing.xs)

                Text(draft.title.isEmpty ? "Untitled offer" : draft.title)
                    .font(SvFont.label)
                    .foregroundStyle(Color.svOnBackground)

                if !draft.description.isEmpty {
                    Text(draft.description)
                        .font(SvFont.bodySmall)
                        .foregroundStyle(Color.svSecondary)
                }

                Spacer().frame(height: SvSpacing.xxl)

                Text("\(daysText)  \(timesText)")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svOnBackground)

                Spacer().frame(height: SvSpacing.sm)

                openNowPill
            }
            .padding(SvSpacing.xl)
        }
        .background(Color.svOnPrimary)
        .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var heroImage: some View {
        if let url = previewImages.first {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle().fill(Color.svImagePlaceholder)
            Image("OfferPreviewImage")
                .resizable()
                .scaledToFill()
                .foregroundStyle(Color.svSecondary)
        }
    }

    private var openNowPill: some View {
        Text("Open now")
            .font(SvFont.captionStrong)
            .foregroundStyle(Color.svOpenNowForeground)
            .padding(.horizontal, SvSpacing.md)
            .padding(.vertical, SvSpacing.xs + 1)
            .background(Color.svOpenNowBackground, in: Capsule())
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: SvSpacing.md) {
            SvSecondaryButton(title: "Edit", action: onBack)
            SvPrimaryButton(
                title: "Publish Offer",
                isLoading: isSaving,
                isEnabled: !isSaving,
                action: onConfirm
            )
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.vertical, SvSpacing.md)
        .background(Color.svBackground)
    }

    // MARK: - Formatting

    private var previewImages: [URL] {
        draft.existingImageUrls + draft.imageUris
    }

    private var metaLine: String {
        "\(categoryName ?? "Restaurant") • Near you"
    }

    /// JUDGMENT CALL: mirrors `Offer.discountDisplayText` (`OfferUiMapper.swift`) — approximate
    /// percentage-style formatting from the raw `discountId` string is acceptable here, this is
    /// display-only formatting for the offer preview card.
    private var discountBadgeText: String? {
        guard let discountId = draft.discountId, !discountId.isEmpty else { return nil }
        if discountId == "custom" {
            return draft.customDiscountText?.isEmpty == false ? draft.customDiscountText : "Custom"
        }
        if discountId == "bogo" { return "Buy 1 Get 1" }
        return "\(discountId)% off"
    }

    private var daysText: String {
        if draft.validDays.count == 7 { return "Every day" }
        let sorted = draft.validDays.sorted()
        if sorted.isEmpty { return "—" }
        if sorted.count == 1 { return shortName(sorted.first!) }
        if isContiguous(sorted) {
            return "\(shortName(sorted.first!)) – \(shortName(sorted.last!))"
        }
        return sorted.map(shortName).joined(separator: ", ")
    }

    /// The Preview screen is only reachable once `AddOfferViewModel.onTapPreview()` has confirmed
    /// `validation.isValid`, which requires both times to be set — the `?? .startOfDay`/`.endOfDay`
    /// fallbacks here are defensive only, never actually hit.
    private var timesText: String {
        "\((draft.validTimeStart ?? .startOfDay).formatted24h) – \((draft.validTimeEnd ?? .endOfDay).formatted24h)"
    }

    private func isContiguous(_ days: [Weekday]) -> Bool {
        let indices = days.compactMap { Weekday.allCases.firstIndex(of: $0) }
        guard indices.count > 1 else { return true }
        for i in 1..<indices.count where indices[i] - indices[i - 1] != 1 {
            return false
        }
        return true
    }

    private func shortName(_ day: Weekday) -> String {
        switch day {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
        }
    }
}

// Local tokens — promote to Color.svSuccess* in the Asset Catalog when the
// design system gains a green palette.
private extension Color {
    static let svOpenNowBackground = Color(red: 0.91, green: 0.97, blue: 0.94)
    static let svOpenNowForeground = Color(red: 0.13, green: 0.59, blue: 0.36)
}

// MARK: - Previews

#Preview("Preview - Filled") {
    NavigationStack {
        OfferPreviewScreen(
            draft: OfferDraft(from: MockOfferRepository.seed[0]),
            categoryName: "Pizza",
            isSaving: false,
            onConfirm: {},
            onBack: {},
            restaurantName: "Bella Italia"
        )
    }
}

#Preview("Preview - Saving") {
    NavigationStack {
        OfferPreviewScreen(
            draft: OfferDraft(from: MockOfferRepository.seed[0]),
            categoryName: "Pizza",
            isSaving: true,
            onConfirm: {},
            onBack: {},
            restaurantName: "Bella Italia"
        )
    }
}
