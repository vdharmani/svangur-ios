import Foundation

enum DeleteAccountEndpoint: Endpoint {
    case deleteAccount

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .deleteAccount:
            return "/owner/account"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .deleteAccount:
            return .delete
        }
    }
}
