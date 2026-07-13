import Foundation

enum DaysEndpoint: Endpoint {
    case getDays(lang: String, tz: String)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .getDays:
            return "/days"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getDays:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getDays(let lang, let tz):
            return [
                URLQueryItem(name: "lang", value: lang),
                URLQueryItem(name: "tz", value: tz)
            ]
        }
    }

    var requiresAuth: Bool { false }
}
