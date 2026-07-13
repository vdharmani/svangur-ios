import Foundation

extension FeaturedItemDTO {
    func toDomain() -> FeaturedItem {
        FeaturedItem(id: id, url: url.flatMap { URL(string: $0) }, title: title)
    }
}

extension BootstrapPayloadDTO {
    func toDomain() -> BootstrapData {
        BootstrapData(
            userCategories: categories.userFilters.map { $0.toDomain() },
            ownerCategories: categories.ownerOptions.map { $0.toDomain() },
            discountFilters: discountOptions.userFilters.map { $0.toDomain() },
            ownerDiscountOptions: discountOptions.ownerOptions.map { $0.toDomain() },
            days: days.items.map { $0.toDomain(currentDay: days.currentDay) },
            featured: featured.map { $0.toDomain() }
        )
    }
}
