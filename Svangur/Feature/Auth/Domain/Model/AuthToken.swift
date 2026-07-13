import Foundation

/// Verified live against `/owner/login`: a single opaque `token` (no separate refresh token —
/// `owner/refresh` re-issues a fresh one using the current bearer token) plus `expires_in`
/// (seconds) and the owner's profile summary.
struct AuthToken: Sendable, Equatable {
    let token: String
    let expiresAt: Date
    let ownerId: Int64
    let ownerNameEn: String
    let ownerNameIs: String
    let ownerEmail: String
    let ownerStatus: String

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
