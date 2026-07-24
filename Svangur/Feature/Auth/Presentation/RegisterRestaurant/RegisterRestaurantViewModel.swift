import SwiftUI
import Combine
import CoreLocation

@MainActor
final class RegisterRestaurantViewModel: ObservableObject {
    // MARK: - Form fields
    @Published var restaurantName: String = "" { didSet { revalidateIfTouched() } }
    @Published var restaurantNameIcelandic: String = "" { didSet { revalidateIfTouched() } }
    @Published var email: String = ""          { didSet { revalidateIfTouched() } }
    @Published var password: String = ""       { didSet { revalidateIfTouched() } }
    @Published var confirmPassword: String = "" { didSet { revalidateIfTouched() } }
    @Published var phoneNumber: String = ""    { didSet { revalidateIfTouched() } }
    @Published var description: String = ""    { didSet { revalidateIfTouched() } }
    @Published var descriptionIcelandic: String = "" { didSet { revalidateIfTouched() } }
    @Published var address: String = ""        { didSet { revalidateIfTouched() } }
    @Published var city: String = ""           { didSet { revalidateIfTouched() } }
    /// No static fallback on purpose — only ever set from the live reverse-geocode result in
    /// `onAppear()`. Stays empty (and the server will reject the submission) if location/geocoding
    /// fails, rather than silently defaulting to a guessed country.
    @Published var country: String = ""
    @Published var imageRefs: [URL] = []
    @Published var documentRef: URL?
    @Published var openingHours: [Weekday: DaySchedule] = RegisterRestaurantViewModel.defaultOpeningHours()
    @Published var isEditing: Bool

    /// Which restaurant-name language field(s) are shown. At least one is always selected —
    /// toggling the only-selected language is a no-op rather than leaving both off.
    @Published private(set) var isEnglishNameSelected = true
    @Published private(set) var isIcelandicNameSelected = true

    /// Which description language field(s) are shown. Same at-least-one-selected rule as the
    /// name toggles above.
    @Published private(set) var isEnglishDescriptionSelected = true
    @Published private(set) var isIcelandicDescriptionSelected = true

    /// Google Places Autocomplete suggestions for the current `address` text.
    @Published private(set) var addressSuggestions: [PlaceSuggestion] = []
    /// `nonisolated(unsafe)`: only ever mutated from `@MainActor` methods, except for the
    /// `cancel()` call in `deinit`, which is inherently exclusive (no other reference to
    /// `self` can exist by the time `deinit` runs) and `Task.cancel()` itself is thread-safe.
    nonisolated(unsafe) private var addressSearchTask: Task<Void, Never>?
    /// Set right before a suggestion overwrites `address`, so that assignment doesn't
    /// immediately re-trigger a search against its own result.
    private var lastSelectedAddress: String?

    // MARK: - State
    @Published private(set) var state: RegisterRestaurantUiState = .idle
    @Published private(set) var validation = RegistrationValidation()
    /// Best-effort — `nil` if the user denied permission or a fix couldn't be obtained;
    /// registration still proceeds without coordinates in that case.
    @Published private(set) var capturedLatitude: Double?
    @Published private(set) var capturedLongitude: Double?

    private var hasAttemptedSubmit = false
    /// Set only by the final "Submit for Approval" tap — gates display of the Business Details
    /// step's own errors (address/city/document) so they don't appear the moment step 2 is
    /// reached via "Continue", before the user has touched anything on that step.
    private var hasAttemptedFinalSubmit = false

    private let registerUseCase: RegisterRestaurantUseCaseProtocol
    private let validate: ValidateCredentialsUseCaseProtocol
    private let locationService: LocationServiceProtocol
    private let placesService: PlacesServiceProtocol

    init(
        registerUseCase: RegisterRestaurantUseCaseProtocol,
        validate: ValidateCredentialsUseCaseProtocol,
        locationService: LocationServiceProtocol,
        placesService: PlacesServiceProtocol,
        isEditing: Bool = false
    ) {
        self.registerUseCase = registerUseCase
        self.validate = validate
        self.locationService = locationService
        self.placesService = placesService
        self.isEditing = isEditing
    }

    deinit {
        addressSearchTask?.cancel()
    }

    var canSubmit: Bool {
        !restaurantName.isEmpty && !email.isEmpty &&
        !password.isEmpty && confirmPassword == password &&
        !phoneNumber.isEmpty && !description.isEmpty &&
        !address.isEmpty &&
        !imageRefs.isEmpty && documentRef != nil &&
        state != .submitting
    }

    /// Validates only the fields collected on the Basic Info step (excludes `document`, which
    /// is collected on the Business Details step) — called from the "Continue" button so the
    /// user can't advance past step 1 with invalid/empty fields.
    func validateBasicInfoStep() -> Bool {
        hasAttemptedSubmit = true
        revalidate()
        return validation.restaurantName == nil &&
            validation.restaurantNameIcelandic == nil &&
            validation.email == nil &&
            validation.password == nil &&
            validation.confirmPassword == nil &&
            validation.phoneNumber == nil &&
            validation.description == nil &&
            validation.descriptionIcelandic == nil &&
            validation.images == nil
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

    // MARK: - Address autocomplete

    /// User tapped a Places suggestion — replaces the typed text with the full formatted
    /// address, clears the dropdown, and fetches that place's city/country/coordinate so they
    /// reflect the address actually picked rather than the device's current GPS location.
    func selectAddressSuggestion(_ suggestion: PlaceSuggestion) {
        addressSearchTask?.cancel()
        lastSelectedAddress = suggestion.description
        address = suggestion.description
        addressSuggestions = []
        Task {
            if let details = try? await placesService.placeDetails(placeID: suggestion.id) {
                if let city = details.city { self.city = city }
                if let country = details.country { self.country = country }
                capturedLatitude = details.latitude
                capturedLongitude = details.longitude
            }
            // Billed as part of the session that started with the autocomplete search —
            // reset only now, after the Details call, so the next search starts fresh.
            await placesService.resetSession()
        }
    }

    /// Triggered only when the user taps the keyboard's "Search" button — no longer searches
    /// live on every keystroke, so a lookup only fires on explicit intent.
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

    // MARK: - Schedule mutators
    /// Set when `toggleDayOpen(_:)` refuses to close the last remaining open day, OR when
    /// `submit()` finds a day whose Close Time isn't after its Open Time — displayed under the
    /// Opening Hours table, cleared as soon as the underlying problem is resolved.
    @Published private(set) var openingHoursError: String?

    /// Enabled days whose Close Time is at or before their Open Time — populated by `submit()`,
    /// and re-checked after every edit once non-empty so fixing a flagged day clears its
    /// highlight live. Drives the red highlight on each invalid day's row.
    @Published private(set) var invalidOpeningHoursDays: Set<Weekday> = []

    func toggleDayOpen(_ day: Weekday) {
        var schedule = openingHours[day] ?? .standardOpen
        if schedule.isOpen {
            let openDayCount = Weekday.allCases.filter { (openingHours[$0] ?? .standardOpen).isOpen }.count
            guard openDayCount > 1 else {
                openingHoursError = "Please keep 1 day open"
                return
            }
        }
        openingHoursError = nil
        schedule.isOpen.toggle()
        openingHours[day] = schedule
        refreshOpeningHoursValidationIfNeeded()
    }

    func setOpenTime(_ time: HourMinute, for day: Weekday) {
        var schedule = openingHours[day] ?? .standardOpen
        schedule.openTime = time
        openingHours[day] = schedule
        refreshOpeningHoursValidationIfNeeded()
    }

    func setCloseTime(_ time: HourMinute, for day: Weekday) {
        var schedule = openingHours[day] ?? .standardOpen
        schedule.closeTime = time
        openingHours[day] = schedule
        refreshOpeningHoursValidationIfNeeded()
    }

    /// Re-runs the opening-hours time-range check after an edit — but only once `submit()` has
    /// already surfaced it, so fixing a flagged day's times clears its highlight/message
    /// immediately instead of requiring another Save tap. Never runs before the first Save
    /// attempt, matching this screen's existing "errors appear on submit, then update live"
    /// pattern (see `hasAttemptedFinalSubmit`).
    private func refreshOpeningHoursValidationIfNeeded() {
        guard !invalidOpeningHoursDays.isEmpty else { return }
        let stillInvalid = Self.invalidOpeningHoursDays(in: openingHours)
        invalidOpeningHoursDays = Set(stillInvalid)
        openingHoursError = stillInvalid.isEmpty ? nil : Self.openingHoursErrorMessage(for: stillInvalid)
    }

    /// Enabled days (in Monday–Sunday order) whose Close Time isn't after their Open Time.
    private static func invalidOpeningHoursDays(in schedule: [Weekday: DaySchedule]) -> [Weekday] {
        func minutes(_ t: HourMinute) -> Int { t.hour * 60 + t.minute }
        return Weekday.allCases.filter { day in
            guard let daySchedule = schedule[day], daySchedule.isOpen else { return false }
            return minutes(daySchedule.closeTime) <= minutes(daySchedule.openTime)
        }
    }

    private static func openingHoursErrorMessage(for days: [Weekday]) -> String {
        let names = days.map(\.fullName)
        let joined: String
        switch names.count {
        case 1:
            joined = names[0]
        case 2:
            joined = "\(names[0]) and \(names[1])"
        default:
            joined = names.dropLast().joined(separator: ", ") + ", and \(names.last ?? "")"
        }
        return "Please fix the invalid opening hours for \(joined)."
    }

    // MARK: - Image / document mutators
    @Published private(set) var imageSizeErrorMessage: String?

    func clearImageSizeError() {
        imageSizeErrorMessage = nil
    }

    func flagOversizedImage() {
        imageSizeErrorMessage = "Restaurants pictures size should be less than 5 MB"
    }

    func addImage(_ url: URL) {
        guard imageRefs.count < ValidateCredentialsUseCase.maxImageCount else { return }
        imageRefs.append(url)
        revalidateIfTouched()
    }

    func removeImage(at index: Int) {
        guard imageRefs.indices.contains(index) else { return }
        imageRefs.remove(at: index)
        revalidateIfTouched()
    }

    func setDocument(_ url: URL?) {
        documentRef = url
        revalidateIfTouched()
    }

    /// Best-effort auto-fill from the device's current location — triggered from the screen's
    /// `.task { }` on appear, never from `init`. Only fills fields the user hasn't already
    /// typed into, so it never clobbers a manual edit or a re-appear after editing.
    /// Deliberately does NOT fill `address` — the user always types/searches that themselves,
    /// since a device-location guess is often wrong for a business address.
    func onAppear() async {
        guard let coordinate = try? await locationService.currentLocation() else { return }
        capturedLatitude = coordinate.latitude
        capturedLongitude = coordinate.longitude

        guard let placemark = try? await locationService.reverseGeocode(coordinate) else { return }
        if city.isEmpty, let value = placemark.city { city = value }
        if let value = placemark.country { country = value }
    }

    // MARK: - Submit
    func submit() async {
        hasAttemptedSubmit = true
        hasAttemptedFinalSubmit = true
        revalidate()

        let invalidDays = Self.invalidOpeningHoursDays(in: openingHours)
        invalidOpeningHoursDays = Set(invalidDays)
        if !invalidDays.isEmpty {
            openingHoursError = Self.openingHoursErrorMessage(for: invalidDays)
        }

        guard validation.isValid, invalidDays.isEmpty else { return }

        state = .submitting
        // Best-effort — prompts for permission if not yet determined. A denial or failed fix
        // doesn't block registration; it just proceeds without coordinates.
        if let coordinate = try? await locationService.currentLocation() {
            capturedLatitude = coordinate.latitude
            capturedLongitude = coordinate.longitude
        }
        do throws(AppError) {
            try await registerUseCase.execute(currentRegistration())
            state = .submitted
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func revalidateIfTouched() {
        guard hasAttemptedSubmit else { return }
        revalidate()
    }

    /// Runs the full-form validation, then — unless the user has actually attempted the final
    /// submit — clears the Business Details step's own fields so their errors can't surface
    /// while the user is still filling out step 1 or has only just arrived at step 2.
    private func revalidate() {
        var result = validate.validateRegistration(currentValidationInput())
        if !hasAttemptedFinalSubmit {
            result.address = nil
            result.city = nil
            result.document = nil
        }
        validation = result
    }

    /// The English name when English is selected, otherwise mirrors the Icelandic name so an
    /// English-only-deselected restaurant doesn't submit a blank `name_en`.
    private var effectiveRestaurantName: String {
        isEnglishNameSelected ? restaurantName : restaurantNameIcelandic
    }

    /// The Icelandic name when Icelandic is selected, otherwise mirrors the English name.
    private var effectiveRestaurantNameIcelandic: String {
        isIcelandicNameSelected ? restaurantNameIcelandic : restaurantName
    }

    /// The English description when English is selected, otherwise mirrors the Icelandic
    /// description so an English-only-deselected restaurant doesn't submit a blank
    /// `description_en`.
    private var effectiveDescription: String {
        isEnglishDescriptionSelected ? description : descriptionIcelandic
    }

    /// The Icelandic description when Icelandic is selected, otherwise mirrors the English one.
    private var effectiveDescriptionIcelandic: String {
        isIcelandicDescriptionSelected ? descriptionIcelandic : description
    }

    private func currentValidationInput() -> RegistrationValidationInput {
        RegistrationValidationInput(
            restaurantName: effectiveRestaurantName,
            restaurantNameIcelandic: effectiveRestaurantNameIcelandic,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            phoneNumber: phoneNumber,
            description: effectiveDescription,
            descriptionIcelandic: effectiveDescriptionIcelandic,
            address: address,
            city: city,
            imageCount: imageRefs.count,
            hasDocument: documentRef != nil
        )
    }

    private func currentRegistration() -> RestaurantRegistration {
        RestaurantRegistration(
            restaurantName: effectiveRestaurantName.trimmingCharacters(in: .whitespacesAndNewlines),
            restaurantNameIcelandic: effectiveRestaurantNameIcelandic.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespaces),
            password: password,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces),
            description: effectiveDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            descriptionIcelandic: effectiveDescriptionIcelandic.trimmingCharacters(in: .whitespacesAndNewlines),
            imageRefs: imageRefs,
            documentRef: documentRef,
            openingHours: openingHours,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: capturedLatitude,
            longitude: capturedLongitude
        )
    }

    private static func defaultOpeningHours() -> [Weekday: DaySchedule] {
        Weekday.allCases.reduce(into: [Weekday: DaySchedule]()) { dict, day in
            dict[day] = .standardOpen
        }
    }

}

// MARK: - Preview Factory
extension RegisterRestaurantViewModel {
    @MainActor
    static func previewInstance(isEditing: Bool = false,state: RegisterRestaurantUiState = .idle) -> RegisterRestaurantViewModel {
        let vm = RegisterRestaurantViewModel(
            registerUseCase: FakeRegisterUseCase(),
            validate: ValidateCredentialsUseCase(),
            locationService: FakeLocationService(),
            placesService: FakePlacesService(),
            isEditing: isEditing
        )
                if isEditing {
                    vm.restaurantName = "The Icelandic Bistro"
                    vm.restaurantNameIcelandic = "Íslenski Bistróinn"
                    vm.email = "info@bistro.is"
                    vm.phoneNumber = "555-1234"
                    vm.description = "A lovely place for shark meat."
                    vm.descriptionIcelandic = "Yndislegur staður fyrir hákarl."
                    vm.address = "Laugavegur 1"
                    vm.city = "Reykjavik"
                }
        vm.state = state
        return vm
    }
}

private struct FakeRegisterUseCase: RegisterRestaurantUseCaseProtocol {
    func execute(_ registration: RestaurantRegistration) async throws(AppError) {}
}

private struct FakeLocationService: LocationServiceProtocol {
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus { .authorizedWhenInUse }
    func currentLocation() async throws(AppError) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426)
    }
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws(AppError) -> PlacemarkInfo {
        PlacemarkInfo(address: "Laugavegur 1", city: "Reykjavik", country: "Iceland")
    }
}

private struct FakePlacesService: PlacesServiceProtocol {
    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion] {
        [PlaceSuggestion(id: "1", description: "\(query), Reykjavik, Iceland")]
    }
    func placeDetails(placeID: String) async throws(AppError) -> PlaceDetails {
        PlaceDetails(
            formattedAddress: "Laugavegur 1, 101 Reykjavik, Iceland",
            city: "Reykjavik",
            country: "Iceland",
            latitude: 64.1466,
            longitude: -21.9426
        )
    }
    func resetSession() async {}
}
