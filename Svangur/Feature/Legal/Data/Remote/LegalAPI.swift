import Foundation

// Android builds this as an absolute `@Url` request by stripping the trailing `api/`
// off the base URL and appending `legal/{type}?lang={lang}` — the real final URL lives
// under the bare host (`http://161.97.132.85:3688/legal/...`), NOT under `/api`.
enum LegalEndpoint: Endpoint {
    case terms(lang: String)
    case privacy(lang: String)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688")! }

    var path: String {
        switch self {
        case .terms:
            return "/legal/terms"
        case .privacy:
            return "/legal/privacy"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .terms(let lang), .privacy(let lang):
            return [URLQueryItem(name: "lang", value: lang)]
        }
    }

    // Response is raw `text/html`, not JSON — no `Content-Type`/`Accept: application/json` needed.
    var headers: [String: String] {
        ["Accept": "text/html"]
    }

    var requiresAuth: Bool { false }
}
