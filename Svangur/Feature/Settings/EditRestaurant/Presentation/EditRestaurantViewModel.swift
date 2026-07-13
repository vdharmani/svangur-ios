import SwiftUI

@MainActor
@Observable
final class EditRestaurantViewModel {
    var nameEn: String = ""
    var nameIs: String = ""
    /// Read-only — the update API has no `email` field, so this is display-only.
    private(set) var adminEmail: String = ""
    var phoneNumber: String = ""
    var descriptionEn: String = ""
    var descriptionIs: String = ""
    var address: String = ""
    var city: String = ""
    var country: String = ""
    var website: String = ""
    var openingHours: [Weekday: EditDaySchedule] = [:]
    /// Newly picked local images to upload alongside the update — the API only accepts new
    /// files to add, not a full replacement list, so already-uploaded photos are shown
    /// read-only via `existingImageURLs` and aren't resubmitted.
    var newImageRefs: [URL] = []
    private(set) var existingImageURLs: [URL] = []

    /// Which restaurant-name language field(s) are shown. At least one is always selected —
    /// toggling the only-selected language is a no-op rather than leaving both off.
    private(set) var isEnglishNameSelected = true
    private(set) var isIcelandicNameSelected = true

    /// Which description language field(s) are shown. Same at-least-one-selected rule as the
    /// name toggles above.
    private(set) var isEnglishDescriptionSelected = true
    private(set) var isIcelandicDescriptionSelected = true

    private(set) var state: EditRestaurantUiState = .loading

    private var latitude: Double?
    private var longitude: Double?

    private let getProfileUseCase: GetRestaurantProfileUseCaseProtocol
    private let updateProfileUseCase: UpdateRestaurantProfileUseCaseProtocol

    init(
        getProfileUseCase: GetRestaurantProfileUseCaseProtocol,
        updateProfileUseCase: UpdateRestaurantProfileUseCaseProtocol
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.updateProfileUseCase = updateProfileUseCase
    }

    var canSubmit: Bool {
        !effectiveNameEn.isEmpty && !effectiveNameIs.isEmpty &&
        !effectiveDescriptionEn.isEmpty && !effectiveDescriptionIs.isEmpty &&
        !address.isEmpty && state != .saving
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
    }

    func toggleIcelandicNameSelected() {
        guard !(isIcelandicNameSelected && !isEnglishNameSelected) else { return }
        isIcelandicNameSelected.toggle()
    }

    // MARK: - Description language toggles
    func toggleEnglishDescriptionSelected() {
        guard !(isEnglishDescriptionSelected && !isIcelandicDescriptionSelected) else { return }
        isEnglishDescriptionSelected.toggle()
    }

    func toggleIcelandicDescriptionSelected() {
        guard !(isIcelandicDescriptionSelected && !isEnglishDescriptionSelected) else { return }
        isIcelandicDescriptionSelected.toggle()
    }

    func toggleDayOpen(_ day: Weekday) {
        let schedule = openingHours[day] ?? EditDaySchedule(day: day)
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

    func addImage(_ url: URL) {
        newImageRefs.append(url)
    }

    func removeNewImage(at index: Int) {
        guard newImageRefs.indices.contains(index) else { return }
        newImageRefs.remove(at: index)
    }

    /// Removes an already-uploaded photo from view only — the update API has no endpoint to
    /// delete an existing restaurant image, so this doesn't affect the server and the photo
    /// reappears the next time the profile is reloaded from `getProfile()`.
    func removeExistingImage(at index: Int) {
        guard existingImageURLs.indices.contains(index) else { return }
        existingImageURLs.remove(at: index)
    }

    func save() async {
        guard canSubmit else { return }
        state = .saving
        do throws(AppError) {
            try await updateProfileUseCase.execute(params: currentParams())
            state = .saved
        } catch {
            state = .error(error.displayMessage)
        }
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
            updateProfileUseCase: FakeUpdateRestaurantProfileUseCase()
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
