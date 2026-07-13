import Foundation

struct User: Sendable, Equatable {
    let id: String
    let name: String
    let email: String
    let avatarUrl: URL?
    let memberSince: Date
}
