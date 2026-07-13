import Foundation

final class EditRestaurantRepositoryImpl: EditRestaurantRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getProfile() async throws(AppError) -> RestaurantEditData {
        try await apiCall {
            let envelope: ProfileEnvelopeDTO = try await apiClient.execute(EditRestaurantEndpoint.getProfile)
            return envelope.data.toDomain()
        }
    }

    func updateProfile(params: ProfileUpdateParams) async throws(AppError) {
        try await apiCall {
            var form = MultipartFormData()
            form.appendField(name: "name_en", value: params.nameEn)
            form.appendField(name: "name_is", value: params.nameIs)
            form.appendField(name: "phone", value: params.phone)
            form.appendField(name: "description_en", value: params.descriptionEn)
            form.appendField(name: "description_is", value: params.descriptionIs)
            form.appendField(name: "address", value: params.address)
            form.appendField(name: "city", value: params.city)
            form.appendField(name: "country", value: params.country)

            if let latitude = params.latitude {
                form.appendField(name: "latitude", value: String(latitude))
            }
            if let longitude = params.longitude {
                form.appendField(name: "longitude", value: String(longitude))
            }
            if let website = params.website {
                form.appendField(name: "website", value: website)
            }

            let openingHoursWire = params.openingHours.map {
                OpeningHourWireDTO(day: $0.day, start: $0.start, end: $0.end, isOpen: $0.isOpen)
            }
            let openingHoursData = try JSONEncoder().encode(openingHoursWire)
            let openingHoursJSON = String(data: openingHoursData, encoding: .utf8) ?? "[]"
            form.appendField(name: "opening_hours", value: openingHoursJSON)

            for (index, imageURIString) in params.imageUris.enumerated() {
                guard let fileURL = URL(string: imageURIString),
                      let fileData = try? Data(contentsOf: fileURL) else { continue }
                form.appendFile(
                    name: "images",
                    filename: "image_\(index).jpg",
                    mimeType: mimeType(for: fileURL),
                    fileData: fileData
                )
            }

            let body = form.build()
            let _: EmptyResponse = try await apiClient.execute(
                EditRestaurantEndpoint.updateProfile(body: body, boundary: form.boundary)
            )
        }
    }

    func getDashboardRaw(page: Int, limit: Int, lang: String) async throws(AppError) -> Data {
        try await apiCall {
            try await apiClient.executeRaw(EditRestaurantEndpoint.getDashboard(page: page, limit: limit, lang: lang))
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        default:
            return "image/jpeg"
        }
    }
}

/// Private wire-shape mirror of `ProfileOpeningHourDTO`, used only to JSON-encode the
/// "opening_hours" multipart text field with the exact wire keys (day/start/end/is_open).
/// The domain `OpeningHourParam` stays a plain Sendable struct with no encoding concerns.
private struct OpeningHourWireDTO: Encodable, Sendable {
    let day: String
    let start: String?
    let end: String?
    let isOpen: Bool

    enum CodingKeys: String, CodingKey {
        case day
        case start
        case end
        case isOpen = "is_open"
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
