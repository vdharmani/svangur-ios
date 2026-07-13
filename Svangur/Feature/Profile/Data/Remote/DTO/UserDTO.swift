import Foundation

struct UserDTO: Codable, Sendable {
    let userId: String
    let fullName: String
    let email: String
    let avatarUrl: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
