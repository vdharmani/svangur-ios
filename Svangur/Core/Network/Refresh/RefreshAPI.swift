import Foundation

// Android calls this synchronously from an OkHttp Authenticator on a 401.
// This is purely a Data-layer endpoint port — wiring it into APIClient's
// 401-retry/authenticator flow is an app-wide interceptor concern and is
// explicitly out of scope here.
enum RefreshEndpoint: Endpoint {
    case refresh

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .refresh:
            return "/owner/refresh"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .refresh:
            return .post(idempotencyKey: nil)
        }
    }
}
