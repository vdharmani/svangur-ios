import Foundation

enum BootstrapEndpoint: Endpoint {
    case getBootstrap(lang: String, tz: String, featuredLimit: Int)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String { "/bootstrap" }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getBootstrap(let lang, let tz, let featuredLimit):
            return [
                URLQueryItem(name: "lang", value: lang),
                URLQueryItem(name: "tz", value: tz),
                URLQueryItem(name: "featured_limit", value: String(featuredLimit))
            ]
        }
    }

    var requiresAuth: Bool { false }
}
