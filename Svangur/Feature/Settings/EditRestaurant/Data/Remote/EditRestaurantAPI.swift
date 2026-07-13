import Foundation

enum EditRestaurantEndpoint: Endpoint {
    case getProfile
    case updateProfile(body: Data, boundary: String)
    /// Combined dashboard view. Verified live that this route exists and requires a Bearer
    /// token (401 "Missing token" without one) — the response BODY shape is unverified, since
    /// this sandbox has no owner credentials to inspect an authenticated response. Decode via
    /// `executeRaw` until the real shape can be confirmed and a proper DTO added.
    case getDashboard(page: Int, limit: Int, lang: String)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .getProfile, .updateProfile:
            return "/owner/profile"
        case .getDashboard:
            return "/owner/dashboard"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getProfile, .getDashboard:
            return .get
        case .updateProfile:
            return .put()
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getDashboard(let page, let limit, let lang):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "lang", value: lang)
            ]
        default:
            return nil
        }
    }

    var headers: [String: String] {
        switch self {
        case .getProfile, .getDashboard:
            return ["Content-Type": "application/json", "Accept": "application/json"]
        case .updateProfile(_, let boundary):
            return ["Content-Type": "multipart/form-data; boundary=\(boundary)", "Accept": "application/json"]
        }
    }

    var body: Data? {
        switch self {
        case .getProfile, .getDashboard:
            return nil
        case .updateProfile(let body, _):
            return body
        }
    }
}
