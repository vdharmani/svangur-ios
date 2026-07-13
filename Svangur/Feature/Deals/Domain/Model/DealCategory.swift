import Foundation

struct DealCategory: Sendable, Equatable {
    let id: String
    let slug: String
    let nameEn: String
    let nameIs: String
    let sortOrder: Int

    init(id: String, slug: String, nameEn: String, nameIs: String, sortOrder: Int = 0) {
        self.id = id
        self.slug = slug
        self.nameEn = nameEn
        self.nameIs = nameIs
        self.sortOrder = sortOrder
    }
}
