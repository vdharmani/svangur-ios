import Foundation

enum UserEndpoint: Endpoint {
    case getUser(id: String)

    var baseURL: URL { URL(string: "https://api.svangur.com")! }

    var path: String {
        switch self {
        case .getUser(let id):
            return "/v1/users/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUser:
            return .get
        }
    }
}
