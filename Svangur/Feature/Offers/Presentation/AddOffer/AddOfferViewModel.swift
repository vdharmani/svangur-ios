import SwiftUI

enum AddOfferField: Hashable, CaseIterable {
    case title, description, category, discount, validDays, validTime
}

@MainActor
@Observable
final class AddOfferViewModel {
    private(set) var loadState: AddOfferLoadState = .ready
    private(set) var effect: AddOfferUiEffect?
    private(set) var validation = OfferDraftValidationErrors()
    private(set) var showPreview = false

    /// Fields the user has actually interacted with, plus whether a Save/Preview attempt has been
    /// made. `displayError(for:)` uses this so selecting one field (e.g. discount) doesn't surface
    /// validation errors for every other untouched field on the form.
    private(set) var touchedFields: Set<AddOfferField> = []
    private(set) var hasAttemptedSave = false

    /// Real, dynamic owner categories (`GET /categories` via `DealRepositoryProtocol`).
    /// Falls back to `Self.fallbackCategories` if the fetch fails or returns empty, so the
    /// category picker always has something selectable.
    private(set) var categories: [DealCategory] = []

    /// Real, dynamic owner discount options (`GET /discount-options` via `DealRepositoryProtocol`).
    /// Falls back to `Self.fallbackDiscountOptions` if the fetch fails or returns empty, so the
    /// discount picker always has something selectable.
    private(set) var discountOptions: [DiscountOwnerOption] = []

    var draft: OfferDraft = .empty {
        didSet { revalidate() }
    }

    let mode: AddOfferMode

    private let getOfferUseCase: GetOfferUseCaseProtocol
    private let createOfferUseCase: CreateOfferUseCaseProtocol
    private let updateOfferUseCase: UpdateOfferUseCaseProtocol
    private let validateDraftUseCase: ValidateOfferDraftUseCaseProtocol
    private let dealRepository: DealRepositoryProtocol

    init(
        mode: AddOfferMode,
        getOfferUseCase: GetOfferUseCaseProtocol,
        createOfferUseCase: CreateOfferUseCaseProtocol,
        updateOfferUseCase: UpdateOfferUseCaseProtocol,
        validateDraftUseCase: ValidateOfferDraftUseCaseProtocol,
        dealRepository: DealRepositoryProtocol
    ) {
        self.mode = mode
        self.getOfferUseCase = getOfferUseCase
        self.createOfferUseCase = createOfferUseCase
        self.updateOfferUseCase = updateOfferUseCase
        self.validateDraftUseCase = validateDraftUseCase
        self.dealRepository = dealRepository
    }

    var isValid: Bool { validation.isValid }

    func markTouched(_ field: AddOfferField) {
        touchedFields.insert(field)
    }

    func displayError(for field: AddOfferField) -> ValidationError? {
        guard hasAttemptedSave || touchedFields.contains(field) else { return nil }
        switch field {
        case .title:      return validation.title
        case .description: return validation.description
        case .category:   return validation.category
        case .discount:   return validation.discount
        case .validDays:  return validation.validDays
        case .validTime:  return validation.validTime
        }
    }

    var titleCharCountText: String {
        "\(draft.title.count) / \(ValidateOfferDraftUseCase.titleMaxLength)"
    }
    var descriptionCharCountText: String {
        "\(draft.description.count) / \(ValidateOfferDraftUseCase.descriptionMaxLength)"
    }

    /// Images currently shown in the picker grid — existing server images first, then newly
    /// staged local files. `removeImage(at:)` figures out which underlying array an index
    /// belongs to.
    var displayImageUrls: [URL] {
        draft.existingImageUrls + draft.imageUris
    }

    func onAppear(lang: String) async {
        await loadCategories(lang: lang)
        await loadDiscountOptions()

        guard case .edit(let id) = mode else { return }
        loadState = .loadingExisting
        do throws(AppError) {
            let offer = try await getOfferUseCase.execute(id: id)
            draft = OfferDraft(from: offer)
            loadState = .ready
        } catch {
            loadState = .error(error.displayMessage)
        }
    }

    func onTapPreview() {
        hasAttemptedSave = true
        revalidate()
        guard isValid else { return }
        showPreview = true
    }

    func dismissPreview() {
        showPreview = false
    }

    func save() async {
        hasAttemptedSave = true
        revalidate()
        guard isValid else { return }
        loadState = .saving
        do throws(AppError) {
            switch mode {
            case .create:
                try await createOfferUseCase.execute(draft: draft)
            case .edit(let id):
                try await updateOfferUseCase.execute(id: id, draft: draft)
            }
            loadState = .ready
            showPreview = false
            effect = .saved
        } catch {
            loadState = .error(error.displayMessage)
        }
    }

    func consumeEffect() {
        effect = nil
    }

    func addImage(_ url: URL) {
        guard displayImageUrls.count < ValidateOfferDraftUseCase.maxImageCount else { return }
        draft.imageUris.append(url)
    }

    func removeImage(at index: Int) {
        if index < draft.existingImageUrls.count {
            draft.existingImageUrls.remove(at: index)
            if index < draft.existingImageIds.count {
                let removedId = draft.existingImageIds.remove(at: index)
                draft.removedImageIds.append(removedId)
            }
        } else {
            let newIndex = index - draft.existingImageUrls.count
            guard draft.imageUris.indices.contains(newIndex) else { return }
            draft.imageUris.remove(at: newIndex)
        }
    }

    func toggleValidDay(_ day: Weekday) {
        markTouched(.validDays)
        if draft.validDays.contains(day) {
            draft.validDays.remove(day)
        } else {
            draft.validDays.insert(day)
        }
    }

    func setEveryDay() {
        markTouched(.validDays)
        draft.validDays = Set(Weekday.allCases)
    }

    private func revalidate() {
        validation = validateDraftUseCase.execute(draft)
    }

    private func loadCategories(lang: String) async {
        do throws(AppError) {
            let fetched = try await dealRepository.listOwnerCategories(lang: lang)
            categories = fetched.isEmpty ? Self.fallbackCategories : fetched
        } catch {
            categories = Self.fallbackCategories
        }
    }

    private func loadDiscountOptions() async {
        do throws(AppError) {
            let fetched = try await dealRepository.listOwnerDiscountOptions()
            discountOptions = fetched.isEmpty ? Self.fallbackDiscountOptions : fetched
        } catch {
            discountOptions = Self.fallbackDiscountOptions
        }
    }

    /// JUDGMENT CALL: small hardcoded fallback so the category picker stays functional if
    /// `listOwnerCategories()` fails or the backend returns nothing — NOT meant to be a
    /// faithful mirror of any real category IDs.
    private static let fallbackCategories: [DealCategory] = [
        DealCategory(id: "1", slug: "food", nameEn: "Food", nameIs: "Matur"),
        DealCategory(id: "2", slug: "drinks", nameEn: "Drinks", nameIs: "Drykkir"),
        DealCategory(id: "3", slug: "other", nameEn: "Other", nameIs: "Annað")
    ]

    /// JUDGMENT CALL: small hardcoded fallback mirroring the real `/discount-options` shape, so
    /// the discount picker stays functional if `listOwnerDiscountOptions()` fails or the backend
    /// returns nothing — NOT meant to be a faithful mirror of any real option IDs.
    private static let fallbackDiscountOptions: [DiscountOwnerOption] = [
        DiscountOwnerOption(id: 1, value: "10", kind: "percent", label: "10% off"),
        DiscountOwnerOption(id: 2, value: "15", kind: "percent", label: "15% off"),
        DiscountOwnerOption(id: 3, value: "20", kind: "percent", label: "20% off"),
        DiscountOwnerOption(id: 4, value: "25", kind: "percent", label: "25% off"),
        DiscountOwnerOption(id: 5, value: "30", kind: "percent", label: "30% off"),
        DiscountOwnerOption(id: 6, value: "2_for_1", kind: "2_for_1", label: "2 for 1"),
        DiscountOwnerOption(id: 7, value: "custom", kind: "custom", label: "Custom Offer")
    ]
}

// MARK: - Preview Factory

extension AddOfferViewModel {
    @MainActor
    static func previewInstance(
        mode: AddOfferMode = .create,
        prefilledDraft: OfferDraft = .empty
    ) -> AddOfferViewModel {
        let validate = ValidateOfferDraftUseCase()
        let vm = AddOfferViewModel(
            mode: mode,
            getOfferUseCase: FakeGetOfferUseCase(),
            createOfferUseCase: FakeCreateOfferUseCase(),
            updateOfferUseCase: FakeUpdateOfferUseCase(),
            validateDraftUseCase: validate,
            dealRepository: FakeDealRepository()
        )
        vm.draft = prefilledDraft
        return vm
    }
}

private struct FakeGetOfferUseCase: GetOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) -> Offer { MockOfferRepository.seed[0] }
}
private struct FakeCreateOfferUseCase: CreateOfferUseCaseProtocol {
    func execute(draft: OfferDraft) async throws(AppError) {}
}
private struct FakeUpdateOfferUseCase: UpdateOfferUseCaseProtocol {
    func execute(id: Int64, draft: OfferDraft) async throws(AppError) {}
}
private struct FakeDealRepository: DealRepositoryProtocol {
    func listDeals(
        latitude: Double?,
        longitude: Double?,
        categoryIds: [String],
        minDiscountPercent: Int?,
        day: String?
    ) async throws(AppError) -> [DealListing] { [] }
    func listCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listOwnerCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listDiscountFilters() async throws(AppError) -> [DiscountUserFilter] { [] }
    func listOwnerDiscountOptions() async throws(AppError) -> [DiscountOwnerOption] { [] }
    func getDeal(id: String) async throws(AppError) -> DealListing {
        throw .notFound()
    }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}
