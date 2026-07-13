import Foundation

enum HTTPMethod: Sendable, Equatable {
    case get
    case head
    case delete
    case put(idempotent: Bool = true)
    case post(idempotencyKey: UUID? = nil)

    var isIdempotent: Bool {
        switch self {
        case .get, .delete, .head:
            return true
        case .put(let idempotent):
            return idempotent
        case .post(let key):
            return key != nil
        }
    }

    var rawValue: String {
        switch self {
        case .get: return "GET"
        case .head: return "HEAD"
        case .delete: return "DELETE"
        case .put: return "PUT"
        case .post: return "POST"
        }
    }
}
