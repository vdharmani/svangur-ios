import SwiftUI
import Combine

enum AddOfferField: Hashable, CaseIterable {
    case title, description, category, discount, validDays, validTime, images
}

@MainActor
final class AddOfferViewModel: ObservableObject {
    @Published private(set) var loadState: AddOfferLoadState
    @Published private(set) var effect: AddOfferUiEffect?
    @Published private(set) var validation = OfferDraftValidationErrors()
    @Published private(set) var showPreview = false

    /// Fields the user has actually interacted with, plus whether a Save/Preview attempt has been
    /// made. `displayError(for:)` uses this so selecting one field (e.g. discount) doesn't surface
    /// validation errors for every other untouched field on the form.
    @Published private(set) var touchedFields: Set<AddOfferField> = []
    @Published private(set) var hasAttemptedSave = false

    /// Real, dynamic owner categories (`GET /categories` via `DealRepositoryProtocol`).
    /// Falls back to `Self.fallbackCategories` if the fetch fails or returns empty, so the
    /// category picker always has something selectable.
    @Published private(set) var categories: [DealCategory] = []

    /// Real, dynamic owner discount options (`GET /discount-options` via `DealRepositoryProtocol`).
    /// Falls back to `Self.fallbackDiscountOptions` if the fetch fails or returns empty, so the
    /// discount picker always has something selectable.
    @Published private(set) var discountOptions: [DiscountOwnerOption] = []

    /// Real, dynamic valid-day options (`GET /days` via `GetDaysUseCaseProtocol`). Falls back to
    /// `Self.fallbackDays` if the fetch fails or returns empty, so the Valid Days chips always
    /// have something selectable. `DayItem.key` (`"mon"`..`"sun"`) round-trips through
    /// `Weekday(dayCode:)` to stay compatible with `OfferDraft.validDays: Set<Weekday>`, the wire
    /// format the offer create/update multipart body depends on.
    @Published private(set) var days: [DayItem] = []

    @Published var draft: OfferDraft = .empty {
        didSet { revalidateIfTouched() }
    }

    let mode: AddOfferMode

    private let getOfferUseCase: GetOfferUseCaseProtocol
    private let createOfferUseCase: CreateOfferUseCaseProtocol
    private let updateOfferUseCase: UpdateOfferUseCaseProtocol
    private let validateDraftUseCase: ValidateOfferDraftUseCaseProtocol
    private let dealRepository: DealRepositoryProtocol
    private let getDaysUseCase: GetDaysUseCaseProtocol

    init(
        mode: AddOfferMode,
        getOfferUseCase: GetOfferUseCaseProtocol,
        createOfferUseCase: CreateOfferUseCaseProtocol,
        updateOfferUseCase: UpdateOfferUseCaseProtocol,
        validateDraftUseCase: ValidateOfferDraftUseCaseProtocol,
        dealRepository: DealRepositoryProtocol,
        getDaysUseCase: GetDaysUseCaseProtocol
    ) {
        self.mode = mode
        // Edit mode starts in `.loadingExisting` so the form is never shown with blank fields
        // for the frame before `onAppear` fetches the real offer — `.ready` is only correct as
        // the initial state for a brand-new (empty-by-design) offer.
        self.loadState = mode.isEdit ? .loadingExisting : .ready
        self.getOfferUseCase = getOfferUseCase
        self.createOfferUseCase = createOfferUseCase
        self.updateOfferUseCase = updateOfferUseCase
        self.validateDraftUseCase = validateDraftUseCase
        self.dealRepository = dealRepository
        self.getDaysUseCase = getDaysUseCase
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
        case .images:     return validation.images
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

    /// The category/discount-option/day metadata fetches are independent of the offer fetch, so
    /// they run concurrently rather than one-after-another — in edit mode, that's the difference
    /// between waiting on the sum of four network calls and waiting on the slowest single one.
    func onAppear(lang: String) async {
        async let categoriesTask: Void = loadCategories(lang: lang)
        async let discountOptionsTask: Void = loadDiscountOptions(lang: lang)
        async let daysTask: Void = loadDays(lang: lang)

        if case .edit(let id) = mode {
            do throws(AppError) {
                let offer = try await getOfferUseCase.execute(id: id)
                draft = OfferDraft(from: offer)
                loadState = .ready
            } catch {
                loadState = .error(error.displayMessage)
            }
        }

        _ = await categoriesTask
        _ = await discountOptionsTask
        _ = await daysTask
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
        markTouched(.images)
        draft.imageUris.append(url)
    }

    func removeImage(at index: Int) {
        markTouched(.images)
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

    func toggleValidDay(_ dayItem: DayItem) {
        guard let day = Weekday(dayCode: dayItem.key) else { return }
        toggleValidDay(day)
    }

    func isDaySelected(_ dayItem: DayItem) -> Bool {
        guard let day = Weekday(dayCode: dayItem.key) else { return false }
        return draft.validDays.contains(day)
    }

    func setEveryDay() {
        markTouched(.validDays)
        draft.validDays = Set(Weekday.allCases)
    }

    /// Mirrors `RegisterRestaurantViewModel`'s pattern: validation only actually runs once the
    /// user has attempted a Save (or Preview) — every field edit before that is a no-op here, so
    /// no error surfaces until the user taps Save Offer. After that first attempt, edits
    /// re-validate live so fixed fields clear their errors immediately.
    private func revalidateIfTouched() {
        guard hasAttemptedSave else { return }
        revalidate()
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

    private func loadDiscountOptions(lang: String) async {
        do throws(AppError) {
            let fetched = try await dealRepository.listOwnerDiscountOptions(lang: lang)
            discountOptions = fetched.isEmpty ? Self.fallbackDiscountOptions : fetched
        } catch {
            discountOptions = Self.fallbackDiscountOptions
        }
    }

    private func loadDays(lang: String) async {
        do throws(AppError) {
            let fetched = try await getDaysUseCase.execute(lang: lang, tz: TimeZone.current.identifier)
            days = fetched.isEmpty ? Self.fallbackDays : fetched
        } catch {
            days = Self.fallbackDays
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

    /// JUDGMENT CALL: small hardcoded fallback mirroring the real `/days` shape, so the Valid
    /// Days chips stay functional if `getDaysUseCase.execute()` fails or the backend returns
    /// nothing — NOT meant to be a faithful mirror of the real current-day flag.
    private static let fallbackDays: [DayItem] = Weekday.allCases.map { day in
        DayItem(key: day.dayCode, label: day.shortName, shortLabel: day.shortName, isToday: false)
    }
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
            dealRepository: FakeDealRepository(),
            getDaysUseCase: FakeGetDaysUseCase()
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
        categoryId: String?,
        discountFilter: String?,
        day: String?,
        openNow: Bool?,
        lang: String?,
        page: Int?,
        limit: Int?,
        deviceId: String?
    ) async throws(AppError) -> [DealListing] { [] }
    func listCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listOwnerCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listDiscountFilters(lang: String) async throws(AppError) -> [DiscountUserFilter] { [] }
    func listOwnerDiscountOptions(lang: String) async throws(AppError) -> [DiscountOwnerOption] { [] }
    func getDeal(id: String, lang: String?) async throws(AppError) -> DealListing {
        throw .notFound()
    }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}
private struct FakeGetDaysUseCase: GetDaysUseCaseProtocol {
    func execute(lang: String, tz: String) async throws(AppError) -> [DayItem] { [] }
}
