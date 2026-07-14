import Foundation

actor MockOfferRepository: OfferRepositoryProtocol {
    private var store: [Int64: Offer]
    private var nextId: Int64

    init(seed: [Offer] = MockOfferRepository.seed) {
        var dict: [Int64: Offer] = [:]
        for offer in seed { dict[offer.id] = offer }
        self.store = dict
        self.nextId = (seed.map(\.id).max() ?? 0) + 1
    }

    func getMyOffers(page: Int, limit: Int) async throws(AppError) -> PaginatedResult<Offer> {
        try? await Task.sleep(for: .milliseconds(600))
        let sorted = store.values.sorted { $0.id > $1.id }
        let startIndex = min((page - 1) * limit, sorted.count)
        let endIndex = min(startIndex + limit, sorted.count)
        let pageItems = Array(sorted[startIndex..<endIndex])
        let hasNextPage = endIndex < sorted.count
        return PaginatedResult(
            items: pageItems,
            hasNextPage: hasNextPage,
            nextPage: hasNextPage ? page + 1 : nil
        )
    }

    func getOffer(id: Int64) async throws(AppError) -> Offer {
        try? await Task.sleep(for: .milliseconds(300))
        guard let offer = store[id] else {
            throw .notFound()
        }
        return offer
    }

    func createOffer(_ draft: OfferDraft) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(800))
        let id = nextId
        nextId += 1
        let offer = Offer(
            id: id,
            restaurantId: 1,
            titleEn: draft.title,
            titleIs: draft.titleIs.isEmpty ? draft.title : draft.titleIs,
            descriptionEn: draft.description,
            descriptionIs: draft.descriptionIs.isEmpty ? nil : draft.descriptionIs,
            categoryId: draft.categoryId,
            discountValue: draft.discountId,
            customDiscountText: draft.customDiscountText,
            validDays: draft.validDays,
            validTimeStart: draft.validTimeStart,
            validTimeEnd: draft.validTimeEnd,
            status: .approved,
            isActive: true,
            heroImageUrl: draft.existingImageUrls.first,
            imageUrls: draft.existingImageUrls,
            imageIds: draft.existingImageIds,
            views: 0,
            clicks: 0
        )
        store[id] = offer
    }

    func updateOffer(id: Int64, draft: OfferDraft) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(600))
        guard let existing = store[id] else { throw .notFound() }
        let updated = Offer(
            id: existing.id,
            restaurantId: existing.restaurantId,
            titleEn: draft.title,
            titleIs: draft.titleIs.isEmpty ? draft.title : draft.titleIs,
            descriptionEn: draft.description,
            descriptionIs: draft.descriptionIs.isEmpty ? nil : draft.descriptionIs,
            categoryId: draft.categoryId ?? existing.categoryId,
            discountValue: draft.discountId ?? existing.discountValue,
            customDiscountText: draft.customDiscountText,
            validDays: draft.validDays,
            validTimeStart: draft.validTimeStart,
            validTimeEnd: draft.validTimeEnd,
            status: existing.status,
            isActive: existing.isActive,
            heroImageUrl: draft.existingImageUrls.first ?? existing.heroImageUrl,
            imageUrls: draft.existingImageUrls,
            imageIds: draft.existingImageIds,
            views: existing.views,
            clicks: existing.clicks
        )
        store[id] = updated
    }

    func deleteOffer(id: Int64) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(400))
        guard store.removeValue(forKey: id) != nil else { throw .notFound() }
    }

    func getAnalytics(id: Int64) async throws(AppError) -> OfferAnalytics {
        try? await Task.sleep(for: .milliseconds(300))
        guard store[id] != nil else { throw .notFound() }
        return OfferAnalytics(
            views: 1245,
            viewsChangePct: 12,
            clicks: 158,
            clicksChangePct: -6,
            mapActions: 42,
            mapActionsChangePct: 3,
            callActions: 18,
            callActionsChangePct: 5,
            websiteActions: 27,
            websiteActionsChangePct: -2,
            period: "last_7_days"
        )
    }
}

extension MockOfferRepository {
    nonisolated static let seed: [Offer] = [
        Offer(
            id: 1,
            restaurantId: 1,
            titleEn: "30% off all pizzas",
            titleIs: "30% afsláttur af öllum pizzum",
            descriptionEn: "Every Wednesday — choose any pizza from our menu and get 30% off the listed price.",
            descriptionIs: nil,
            categoryId: 1,
            discountValue: "30",
            customDiscountText: nil,
            validDays: [.wednesday],
            validTimeStart: TimeOfDay(hour: 11, minute: 0),
            validTimeEnd: TimeOfDay(hour: 22, minute: 0),
            status: .approved,
            isActive: true,
            heroImageUrl: nil,
            imageUrls: [],
            imageIds: [],
            views: 1245,
            clicks: 158
        ),
        Offer(
            id: 2,
            restaurantId: 1,
            titleEn: "2-for-1 burgers",
            titleIs: "2 fyrir 1 hamborgarar",
            descriptionEn: "Buy any burger and get a second one free. Lunch hours only.",
            descriptionIs: nil,
            categoryId: 2,
            discountValue: "bogo",
            customDiscountText: nil,
            validDays: [.monday, .tuesday, .thursday],
            validTimeStart: TimeOfDay(hour: 11, minute: 30),
            validTimeEnd: TimeOfDay(hour: 14, minute: 0),
            status: .approved,
            isActive: true,
            heroImageUrl: nil,
            imageUrls: [],
            imageIds: [],
            views: 860,
            clicks: 91
        ),
        Offer(
            id: 3,
            restaurantId: 1,
            titleEn: "Free dessert with main",
            titleIs: "Frír eftirréttur með aðalrétti",
            descriptionEn: "Order any main course and get a complimentary dessert of the chef's choice.",
            descriptionIs: nil,
            categoryId: 3,
            discountValue: "custom",
            customDiscountText: "Free dessert",
            validDays: [.friday, .saturday],
            validTimeStart: TimeOfDay(hour: 18, minute: 0),
            validTimeEnd: TimeOfDay(hour: 22, minute: 0),
            status: .pendingApproval,
            isActive: false,
            heroImageUrl: nil,
            imageUrls: [],
            imageIds: [],
            views: 340,
            clicks: 22
        )
    ]
}
