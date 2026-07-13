import Foundation

enum SearchEndpoint: Endpoint {
    case search(
        query: String,
        lat: Double? = nil,
        lng: Double? = nil,
        lang: String? = nil,
        page: Int = 1,
        limit: Int = 20,
        deviceId: String? = nil
    )
    case searchByLocation(
        query: String,
        lat: Double? = nil,
        lng: Double? = nil,
        lang: String? = nil,
        page: Int = 1,
        limit: Int = 20,
        deviceId: String? = nil
    )
    case getRecentSearches(deviceId: String, kind: String = "offer")
    case addRecentSearch(body: AddRecentSearchRequestDTO)
    case clearRecentSearches(deviceId: String, kind: String = "offer")

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .search:
            return "/search"
        case .searchByLocation:
            return "/search/location"
        case .getRecentSearches, .addRecentSearch, .clearRecentSearches:
            return "/search/recent"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .search, .searchByLocation, .getRecentSearches:
            return .get
        case .addRecentSearch:
            return .post(idempotencyKey: nil)
        case .clearRecentSearches:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .search(let query, let lat, let lng, let lang, let page, let limit, let deviceId),
             .searchByLocation(let query, let lat, let lng, let lang, let page, let limit, let deviceId):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
            if let lat {
                items.append(URLQueryItem(name: "lat", value: String(lat)))
            }
            if let lng {
                items.append(URLQueryItem(name: "lng", value: String(lng)))
            }
            if let lang {
                items.append(URLQueryItem(name: "lang", value: lang))
            }
            if let deviceId {
                items.append(URLQueryItem(name: "device_id", value: deviceId))
            }
            return items

        case .getRecentSearches(let deviceId, let kind),
             .clearRecentSearches(let deviceId, let kind):
            return [
                URLQueryItem(name: "device_id", value: deviceId),
                URLQueryItem(name: "kind", value: kind),
            ]

        case .addRecentSearch:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .addRecentSearch(let body):
            return try? JSONEncoder().encode(body)
        default:
            return nil
        }
    }

    /// Public/device-based endpoints — no owner Bearer token needed.
    var requiresAuth: Bool { false }
}
