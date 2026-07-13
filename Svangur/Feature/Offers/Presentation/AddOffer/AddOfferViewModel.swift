import SwiftUI

@MainActor
@Observable
final class AddOfferViewModel {
    private(set) var loadState: AddOfferLoadState = .ready
    private(set) var effect: AddOfferUiEffect?
    private(set) var validation = OfferDraftValidationErrors()
    private(set) var showPreview = false

    /// Real, dynamic owner categories (`GET /categories` via `DealRepositoryProtocol`).
    /// Falls back to `Self.fallbackCategories` if the fetch fails or returns empty, so the
    /// category picker always has something selectable.
    private(set) var categories: [DealCategory] = []

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

    func onAppear() async {
        await loadCategories()

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
        revalidate()
        guard isValid else { return }
        showPreview = true
    }

    func dismissPreview() {
        showPreview = false
    }

    func save() async {
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
        if draft.validDays.contains(day) {
            draft.validDays.remove(day)
        } else {
            draft.validDays.insert(day)
        }
    }

    func setEveryDay() {
        draft.validDays = Set(Weekday.allCases)
    }

    private func revalidate() {
        validation = validateDraftUseCase.execute(draft)
    }

    private func loadCategories() async {
        do throws(AppError) {
            let fetched = try await dealRepository.listOwnerCategories()
            categories = fetched.isEmpty ? Self.fallbackCategories : fetched
        } catch {
            categories = Self.fallbackCategories
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
    func listCategories() async throws(AppError) -> [DealCategory] { [] }
    func listOwnerCategories() async throws(AppError) -> [DealCategory] { [] }
    func listDiscountFilters() async throws(AppError) -> [DiscountUserFilter] { [] }
    func listOwnerDiscountOptions() async throws(AppError) -> [DiscountOwnerOption] { [] }
    func getDeal(id: String) async throws(AppError) -> DealListing {
        throw .notFound()
    }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}
