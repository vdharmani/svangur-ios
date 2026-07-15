import Foundation

enum DealEndpoint: Endpoint {
    case listDeals(
        lat: Double? = nil,
        lng: Double? = nil,
        categoryId: String? = nil,
        discountFilter: String? = nil,
        day: String? = nil,
        openNow: Bool? = nil,
        lang: String? = nil,
        page: Int? = nil,
        limit: Int? = nil,
        deviceId: String? = nil
    )
    case listCategories(lang: String? = nil)
    case listDiscountOptions(lang: String? = nil)
    case getDeal(
        id: String,
        lang: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        deviceId: String? = nil
    )
    case trackClick(id: String, body: TrackClickRequestDTO)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .listDeals:
            return "/offers"
        case .listCategories:
            return "/categories"
        case .listDiscountOptions:
            return "/discount-options"
        case .getDeal(let id, _, _, _, _):
            return "/offers/\(id)"
        case .trackClick(let id, _):
            return "/offers/\(id)/click"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listDeals, .listCategories, .listDiscountOptions, .getDeal:
            return .get
        case .trackClick:
            return .post()
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listDeals(let lat, let lng, let categoryId, let discountFilter, let day, let openNow, let lang, let page, let limit, let deviceId):
            var items: [URLQueryItem] = []
            if let lat { items.append(URLQueryItem(name: "lat", value: String(lat))) }
            if let lng { items.append(URLQueryItem(name: "lng", value: String(lng))) }
            if let categoryId { items.append(URLQueryItem(name: "category_id", value: categoryId)) }
            if let discountFilter { items.append(URLQueryItem(name: "discount_filter", value: discountFilter)) }
            if let day { items.append(URLQueryItem(name: "day", value: day)) }
            if let openNow { items.append(URLQueryItem(name: "open_now", value: openNow ? "true" : "false")) }
            if let lang { items.append(URLQueryItem(name: "lang", value: lang)) }
            if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
            if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            if let deviceId { items.append(URLQueryItem(name: "device_id", value: deviceId)) }
            return items.isEmpty ? nil : items

        case .listCategories(let lang):
            guard let lang else { return nil }
            return [URLQueryItem(name: "lang", value: lang)]

        case .listDiscountOptions(let lang):
            guard let lang else { return nil }
            return [URLQueryItem(name: "lang", value: lang)]

        case .getDeal(_, let lang, let lat, let lng, let deviceId):
            var items: [URLQueryItem] = []
            if let lang { items.append(URLQueryItem(name: "lang", value: lang)) }
            if let lat { items.append(URLQueryItem(name: "lat", value: String(lat))) }
            if let lng { items.append(URLQueryItem(name: "lng", value: String(lng))) }
            if let deviceId { items.append(URLQueryItem(name: "device_id", value: deviceId)) }
            return items.isEmpty ? nil : items

        case .trackClick:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .trackClick(_, let body):
            let encoder = JSONEncoder()
            return try? encoder.encode(body)
        default:
            return nil
        }
    }

    /// Public consumer-facing browsing endpoints — no owner Bearer token needed.
    var requiresAuth: Bool { false }
}
