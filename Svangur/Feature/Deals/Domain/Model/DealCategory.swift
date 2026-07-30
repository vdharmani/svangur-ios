import Foundation

struct DealCategory: Sendable, Equatable {
    let id: String
    let slug: String
    let nameEn: String
    let nameIs: String
    let sortOrder: Int
    let iconUrl: String?

    init(
        id: String,
        slug: String,
        nameEn: String,
        nameIs: String,
        sortOrder: Int = 0,
        iconUrl: String? = nil
    ) {
        self.id = id
        self.slug = slug
        self.nameEn = nameEn
        self.nameIs = nameIs
        self.sortOrder = sortOrder
        self.iconUrl = iconUrl
    }
}

extension DealCategory {
    func localizedName(for language: AppLanguage) -> String {
        language == .icelandic ? nameIs : nameEn
    }

    /// Some backends double-escape forward slashes in JSON string values, leaving literal
    /// `\/` sequences in the decoded `iconUrl` rather than a plain `/` — normalize those before
    /// constructing the URL, since `URL(string:)` would otherwise fail to parse them correctly.
    var iconURL: URL? {
        guard let iconUrl else { return nil }
        return URL(string: iconUrl.replacingOccurrences(of: "\\/", with: "/"))
    }
}
