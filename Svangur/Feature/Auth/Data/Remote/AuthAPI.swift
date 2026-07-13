import Foundation

enum AuthEndpoint: Endpoint {
    case login(body: LoginRequestDTO, idempotencyKey: UUID)
    case logout
    case requestPasswordReset(body: PasswordResetRequestDTO, idempotencyKey: UUID)
    case resetPassword(body: PasswordResetConfirmDTO, idempotencyKey: UUID)
    /// Multipart registration. `body`/`boundary` are pre-built by the repository via
    /// `MultipartFormData`, mirroring the pattern used by Images/EditRestaurant uploads.
    case register(body: Data, boundary: String)
    /// Multipart resubmission of the verification document, allowed only when the owner's
    /// account status is `revision_requested`. Requires a Bearer token — see the note on
    /// `headers` below about this app's auth-header attachment still being unimplemented.
    case reviseDocument(body: Data, boundary: String)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .login:                  return "/owner/login"
        case .logout:                 return "/owner/logout"
        case .requestPasswordReset:   return "/owner/forgot-password"
        case .resetPassword:          return "/owner/reset-password"
        case .register:               return "/owner/register"
        case .reviseDocument:         return "/owner/revise-document"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login(_, let key),
             .requestPasswordReset(_, let key),
             .resetPassword(_, let key):
            return .post(idempotencyKey: key)
        case .logout:
            return .post(idempotencyKey: UUID())
        case .register, .reviseDocument:
            return .post(idempotencyKey: nil)
        }
    }

    var headers: [String: String] {
        switch self {
        case .register(_, let boundary), .reviseDocument(_, let boundary):
            return ["Accept": "application/json", "Content-Type": "multipart/form-data; boundary=\(boundary)"]
        default:
            return ["Content-Type": "application/json", "Accept": "application/json"]
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .requestPasswordReset, .resetPassword, .register:
            return false
        case .logout, .reviseDocument:
            return true
        }
    }

    var body: Data? {
        let encoder = JSONEncoder()
        switch self {
        case .login(let body, _):                return try? encoder.encode(body)
        case .requestPasswordReset(let body, _): return try? encoder.encode(body)
        case .resetPassword(let body, _):        return try? encoder.encode(body)
        case .logout:                            return nil
        case .register(let body, _):             return body
        case .reviseDocument(let body, _):        return body
        }
    }
}
