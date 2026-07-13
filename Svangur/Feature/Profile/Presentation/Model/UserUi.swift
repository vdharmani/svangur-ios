import Foundation

struct UserUi: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let email: String
    let avatarUrl: URL?
    let memberSinceText: String
}
