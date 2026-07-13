import Foundation

final class OfferRepositoryImpl: OfferRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getMyOffers() async throws(AppError) -> [Offer] {
        try await apiCall {
            let envelope: OfferListEnvelopeDTO = try await apiClient.execute(
                OfferEndpoint.listOffers(page: 1, limit: 50)
            )
            return envelope.data.items.map { $0.toDomain() }
        }
    }

    func getOffer(id: Int64) async throws(AppError) -> Offer {
        try await apiCall {
            let envelope: OwnerOfferEnvelopeDTO = try await apiClient.execute(OfferEndpoint.getOffer(id: id))
            return envelope.data.toDomain()
        }
    }

    func createOffer(_ draft: OfferDraft) async throws(AppError) {
        try await apiCall {
            let form = Self.buildMultipart(from: draft, includeRemoveImageIds: false)
            let _: CreateOfferResponseDTO = try await apiClient.execute(
                OfferEndpoint.createOffer(body: form.build(), boundary: form.boundary)
            )
        }
    }

    func updateOffer(id: Int64, draft: OfferDraft) async throws(AppError) {
        try await apiCall {
            let form = Self.buildMultipart(from: draft, includeRemoveImageIds: true)
            // The real API returns `{ offer_id, images_removed, images_added }` on update —
            // not a full offer envelope like create/get — so the response is discarded here.
            let _: UpdateOfferResponseDTO = try await apiClient.execute(
                OfferEndpoint.updateOffer(id: id, body: form.build(), boundary: form.boundary)
            )
        }
    }

    func deleteOffer(id: Int64) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(OfferEndpoint.deleteOffer(id: id))
        }
    }

    func getAnalytics(id: Int64) async throws(AppError) -> OfferAnalytics {
        try await apiCall {
            let envelope: OfferAnalyticsEnvelopeDTO = try await apiClient.execute(OfferEndpoint.getAnalytics(id: id))
            return envelope.data.toDomain()
        }
    }

    // MARK: - Private

    /// Builds the exact multipart field set Android's `OfferRepositoryImpl` sends for both
    /// create and update (Android's `updateOffer` sends the same fields, just as optional
    /// parts — sending them unconditionally here is a harmless simplification since the draft
    /// always carries the full form state).
    private static func buildMultipart(from draft: OfferDraft, includeRemoveImageIds: Bool) -> MultipartFormData {
        var form = MultipartFormData()

        let titleEn = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleIsTrimmed = draft.titleIs.trimmingCharacters(in: .whitespacesAndNewlines)
        form.appendField(name: "title_en", value: titleEn)
        form.appendField(name: "title_is", value: titleIsTrimmed.isEmpty ? titleEn : titleIsTrimmed)

        let descriptionEn = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionIsTrimmed = draft.descriptionIs.trimmingCharacters(in: .whitespacesAndNewlines)
        if !descriptionEn.isEmpty {
            form.appendField(name: "description_en", value: descriptionEn)
        }
        if !descriptionIsTrimmed.isEmpty {
            form.appendField(name: "description_is", value: descriptionIsTrimmed)
        } else if !descriptionEn.isEmpty {
            form.appendField(name: "description_is", value: descriptionEn)
        }

        form.appendField(name: "category_id", value: draft.categoryId.map(String.init) ?? "")
        form.appendField(name: "discount_value", value: draft.discountId ?? "")
        if draft.discountId == "custom", let customText = draft.customDiscountText, !customText.isEmpty {
            form.appendField(name: "custom_discount_text", value: customText)
        }

        let sortedDayCodes = draft.validDays.sorted().map(\.dayCode)
        let validDaysJSON = (try? JSONEncoder().encode(sortedDayCodes))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        form.appendField(name: "valid_days", value: validDaysJSON)

        form.appendField(name: "valid_time_start", value: draft.validTimeStart.formatted24h)
        form.appendField(name: "valid_time_end", value: draft.validTimeEnd.formatted24h)

        if includeRemoveImageIds, !draft.removedImageIds.isEmpty {
            form.appendField(name: "remove_image_ids", value: draft.removedImageIds.joined(separator: ","))
        }

        for (index, fileURL) in draft.imageUris.enumerated() {
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }
            form.appendFile(
                name: "images",
                filename: "offer_image_\(index).jpg",
                mimeType: mimeType(for: fileURL),
                fileData: fileData
            )
        }

        return form
    }

    private static func mimeType(for url: URL) -> String {
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

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
