import Foundation

enum ChangePasswordEndpoint: Endpoint {
    case changePassword(body: ChangePasswordRequestDTO)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .changePassword:
            return "/owner/change-password"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .changePassword:
            return .post(idempotencyKey: nil)
        }
    }

    var body: Data? {
        switch self {
        case .changePassword(let body):
            return try? JSONEncoder().encode(body)
        }
    }
}
