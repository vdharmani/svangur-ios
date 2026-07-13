import Foundation

extension UserDTO {
    func toDomain() -> User {
        User(
            id: userId,
            name: fullName,
            email: email,
            avatarUrl: avatarUrl.flatMap { URL(string: $0) },
            memberSince: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}
