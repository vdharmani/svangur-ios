import SwiftUI
import Combine

@MainActor
final class EditRestaurantViewModel: ObservableObject {
    @Published var nameEn: String = ""        { didSet { revalidateIfTouched() } }
    @Published var nameIs: String = ""        { didSet { revalidateIfTouched() } }
    /// Read-only — the update API has no `email` field, so this is display-only.
    @Published private(set) var adminEmail: String = ""
    @Published var phoneNumber: String = ""
    @Published var descriptionEn: String = "" { didSet { revalidateIfTouched() } }
    @Published var descriptionIs: String = "" { didSet { revalidateIfTouched() } }
    @Published var address: String = ""
    @Published var city: String = ""
    @Published var country: String = ""
    /// Google Places Autocomplete suggestions for the current `address` text — populated only
    /// via `searchAddressNow()` (the keyboard's "Search" button), never live as the user types.
    @Published private(set) var addressSuggestions: [PlaceSuggestion] = []
    @Published var website: String = ""
    @Published var openingHours: [Weekday: EditDaySchedule] = [:]
    /// Newly picked local images to upload alongside the update — the API only accepts new
    /// files to add, not a full replacement list, so already-uploaded photos are shown
    /// read-only via `existingImageURLs` and aren't resubmitted.
    @Published var newImageRefs: [URL] = []
    @Published private(set) var existingImageURLs: [URL] = []

    /// Which restaurant-name language field(s) are shown. At least one is always selected —
    /// toggling the only-selected language is a no-op rather than leaving both off.
    @Published private(set) var isEnglishNameSelected = true
    @Published private(set) var isIcelandicNameSelected = true

    /// Which description language field(s) are shown. Same at-least-one-selected rule as the
    /// name toggles above.
    @Published private(set) var isEnglishDescriptionSelected = true
    @Published private(set) var isIcelandicDescriptionSelected = true

    @Published private(set) var state: EditRestaurantUiState = .loading
    @Published private(set) var validation = EditRestaurantValidation()
    private var hasAttemptedSave = false

    private var latitude: Double?
    private var longitude: Double?
    private var lastSelectedAddress: String?
    private var addressSearchTask: Task<Void, Never>?

    private let getProfileUseCase: GetRestaurantProfileUseCaseProtocol
    private let updateProfileUseCase: UpdateRestaurantProfileUseCaseProtocol
    private let placesService: PlacesServiceProtocol

    init(
        getProfileUseCase: GetRestaurantProfileUseCaseProtocol,
        updateProfileUseCase: UpdateRestaurantProfileUseCaseProtocol,
        placesService: PlacesServiceProtocol
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.updateProfileUseCase = updateProfileUseCase
        self.placesService = placesService
    }

    func onAppear() async {
        guard state == .loading else { return }
        do throws(AppError) {
            let data = try await getProfileUseCase.execute()
            apply(data)
            state = .idle
        } catch {
            state = .error(error.displayMessage)
        }
    }

    // MARK: - Name language toggles
    func toggleEnglishNameSelected() {
        guard !(isEnglishNameSelected && !isIcelandicNameSelected) else { return }
        isEnglishNameSelected.toggle()
        revalidateIfTouched()
    }

    func toggleIcelandicNameSelected() {
        guard !(isIcelandicNameSelected && !isEnglishNameSelected) else { return }
        isIcelandicNameSelected.toggle()
        revalidateIfTouched()
    }

    // MARK: - Description language toggles
    func toggleEnglishDescriptionSelected() {
        guard !(isEnglishDescriptionSelected && !isIcelandicDescriptionSelected) else { return }
        isEnglishDescriptionSelected.toggle()
        revalidateIfTouched()
    }

    func toggleIcelandicDescriptionSelected() {
        guard !(isIcelandicDescriptionSelected && !isEnglishDescriptionSelected) else { return }
        isIcelandicDescriptionSelected.toggle()
        revalidateIfTouched()
    }

    /// Set when `toggleDayOpen(_:)` refuses to close the last remaining open day — displayed
    /// under the Opening Hours table, cleared as soon as a toggle actually succeeds.
    @Published private(set) var openingHoursError: String?

    func toggleDayOpen(_ day: Weekday) {
        let schedule = openingHours[day] ?? EditDaySchedule(day: day)
        if !schedule.isClosed {
            let openDayCount = Weekday.allCases.filter { !(openingHours[$0]?.isClosed ?? false) }.count
            guard openDayCount > 1 else {
                openingHoursError = "Please keep 1 day open"
                return
            }
        }
        openingHoursError = nil
        openingHours[day] = EditDaySchedule(
            day: day,
            openTime: schedule.openTime,
            closeTime: schedule.closeTime,
            isClosed: !schedule.isClosed
        )
    }

    func setOpenTime(_ time: String, for day: Weekday) {
        let schedule = openingHours[day] ?? EditDaySchedule(day: day)
        openingHours[day] = EditDaySchedule(
            day: day,
            openTime: time,
            closeTime: schedule.closeTime,
            isClosed: schedule.isClosed
        )
    }

    func setCloseTime(_ time: String, for day: Weekday) {
        let schedule = openingHours[day] ?? EditDaySchedule(day: day)
        openingHours[day] = EditDaySchedule(
            day: day,
            openTime: schedule.openTime,
            closeTime: time,
            isClosed: schedule.isClosed
        )
    }

    // MARK: - Address autocomplete

    /// User tapped a Places suggestion — replaces the typed text with the full formatted
    /// address, clears the dropdown, and fetches that place's city/country/coordinate so they
    /// reflect the address actually picked rather than what was previously on file.
    func selectAddressSuggestion(_ suggestion: PlaceSuggestion) {
        addressSearchTask?.cancel()
        lastSelectedAddress = suggestion.description
        address = suggestion.description
        addressSuggestions = []
        Task {
            if let details = try? await placesService.placeDetails(placeID: suggestion.id) {
                if let city = details.city { self.city = city }
                if let country = details.country { self.country = country }
                latitude = details.latitude
                longitude = details.longitude
            }
            // Billed as part of the session that started with the autocomplete search —
            // reset only now, after the Details call, so the next search starts fresh.
            await placesService.resetSession()
        }
    }

    /// Triggered only when the user taps the keyboard's "Search" button — no live search on
    /// every keystroke.
    func searchAddressNow() {
        addressSearchTask?.cancel()
        guard address != lastSelectedAddress else { return }
        guard address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
            addressSuggestions = []
            return
        }
        let query = address
        addressSearchTask = Task { [weak self] in
            await self?.runAddressSearch(query)
        }
    }

    private func runAddressSearch(_ query: String) async {
        guard let suggestions = try? await placesService.autocomplete(query: query) else { return }
        // The user may have kept typing (or cleared the field) while this request was in
        // flight — only apply results that still match the current text.
        guard !Task.isCancelled, query == address else { return }
        addressSuggestions = suggestions
    }

    func addImage(_ url: URL) {
        newImageRefs.append(url)
        revalidateIfTouched()
    }

    func removeNewImage(at index: Int) {
        guard newImageRefs.indices.contains(index) else { return }
        newImageRefs.remove(at: index)
        revalidateIfTouched()
    }

    /// Removes an already-uploaded photo from view only — the update API has no endpoint to
    /// delete an existing restaurant image, so this doesn't affect the server and the photo
    /// reappears the next time the profile is reloaded from `getProfile()`.
    func removeExistingImage(at index: Int) {
        guard existingImageURLs.indices.contains(index) else { return }
        existingImageURLs.remove(at: index)
        revalidateIfTouched()
    }

    func save() async {
        hasAttemptedSave = true
        revalidate()
        guard validation.isValid else { return }

        state = .saving
        do throws(AppError) {
            try await updateProfileUseCase.execute(params: currentParams())
            state = .saved
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func revalidateIfTouched() {
        guard hasAttemptedSave else { return }
        revalidate()
    }

    private func revalidate() {
        validation = EditRestaurantValidation(
            nameEn: Self.validateRestaurantNameField(effectiveNameEn),
            nameIs: Self.validateRestaurantNameField(effectiveNameIs),
            descriptionEn: effectiveDescriptionEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : nil,
            descriptionIs: effectiveDescriptionIs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : nil,
            images: (existingImageURLs.count + newImageRefs.count) == 0
                ? .custom(messageKey: "Please add at least one image.") : nil
        )
    }

    /// Same minimum length as `ValidateCredentialsUseCase.restaurantNameMinLength` (Register
    /// Restaurant) — kept in sync so both screens enforce an identical restaurant-name policy.
    private static func validateRestaurantNameField(_ name: String) -> ValidationError? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count < ValidateCredentialsUseCase.restaurantNameMinLength {
            return .tooShort(min: ValidateCredentialsUseCase.restaurantNameMinLength)
        }
        return nil
    }

    /// The English name when English is selected, otherwise mirrors the Icelandic name so an
    /// English-only-deselected restaurant doesn't submit a blank `name_en`.
    private var effectiveNameEn: String {
        isEnglishNameSelected ? nameEn : nameIs
    }

    /// The Icelandic name when Icelandic is selected, otherwise mirrors the English name.
    private var effectiveNameIs: String {
        isIcelandicNameSelected ? nameIs : nameEn
    }

    /// The English description when English is selected, otherwise mirrors the Icelandic one.
    private var effectiveDescriptionEn: String {
        isEnglishDescriptionSelected ? descriptionEn : descriptionIs
    }

    /// The Icelandic description when Icelandic is selected, otherwise mirrors the English one.
    private var effectiveDescriptionIs: String {
        isIcelandicDescriptionSelected ? descriptionIs : descriptionEn
    }

    private func apply(_ data: RestaurantEditData) {
        nameEn = data.nameEn
        nameIs = data.nameIs
        adminEmail = data.adminEmail
        phoneNumber = data.phoneNumber
        descriptionEn = data.descriptionEn
        descriptionIs = data.descriptionIs
        address = data.address
        city = data.city
        country = data.country
        website = data.website
        latitude = data.latitude
        longitude = data.longitude
        existingImageURLs = data.restaurantImages.compactMap(URL.init(string:))
        openingHours = Dictionary(uniqueKeysWithValues: data.openingHours.map { ($0.day, $0) })
    }

    private func currentParams() -> ProfileUpdateParams {
        ProfileUpdateParams(
            nameEn: effectiveNameEn.trimmingCharacters(in: .whitespacesAndNewlines),
            nameIs: effectiveNameIs.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phoneNumber.trimmingCharacters(in: .whitespaces),
            descriptionEn: effectiveDescriptionEn.trimmingCharacters(in: .whitespacesAndNewlines),
            descriptionIs: effectiveDescriptionIs.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            website: website.trimmingCharacters(in: .whitespaces).isEmpty ? nil : website,
            openingHours: Weekday.allCases.map { day in
                let schedule = openingHours[day] ?? EditDaySchedule(day: day)
                return OpeningHourParam(
                    day: day.dayCode,
                    start: schedule.isClosed ? nil : schedule.openTime,
                    end: schedule.isClosed ? nil : schedule.closeTime,
                    isOpen: !schedule.isClosed
                )
            },
            imageUris: newImageRefs.map(\.absoluteString)
        )
    }
}

// MARK: - Preview Factory
extension EditRestaurantViewModel {
    @MainActor
    static func previewInstance(state: EditRestaurantUiState = .idle) -> EditRestaurantViewModel {
        let vm = EditRestaurantViewModel(
            getProfileUseCase: FakeGetRestaurantProfileUseCase(),
            updateProfileUseCase: FakeUpdateRestaurantProfileUseCase(),
            placesService: FakePlacesService()
        )
        vm.apply(FakeGetRestaurantProfileUseCase.sample)
        vm.state = state
        return vm
    }
}

private struct FakeGetRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol {
    static let sample = RestaurantEditData(
        nameEn: "The Golden Fork",
        nameIs: "Gullni Gaffall",
        adminEmail: "info@goldenfork.is",
        phoneNumber: "555-1234",
        descriptionEn: "A perfect place for great food, warm vibes, and special offers.",
        descriptionIs: "Fullkominn staður fyrir frábæran mat.",
        address: "Laugavegur 1",
        city: "Reykjavik",
        country: "Iceland",
        latitude: 64.1466,
        longitude: -21.9426,
        website: "https://goldenfork.is",
        openingHours: []
    )

    func execute() async throws(AppError) -> RestaurantEditData { Self.sample }
}

private struct FakeUpdateRestaurantProfileUseCase: UpdateRestaurantProfileUseCaseProtocol {
    func execute(params: ProfileUpdateParams) async throws(AppError) {}
}

private struct FakePlacesService: PlacesServiceProtocol {
    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion] { [] }
    func placeDetails(placeID: String) async throws(AppError) -> PlaceDetails {
        PlaceDetails(formattedAddress: "Laugavegur 1", city: "Reykjavik", country: "Iceland", latitude: 64.1466, longitude: -21.9426)
    }
    func resetSession() async {}
}
