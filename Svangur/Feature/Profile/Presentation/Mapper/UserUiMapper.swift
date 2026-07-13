import Foundation

extension User {
    func toUi() -> UserUi {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return UserUi(
            id: id,
            displayName: name,
            email: email,
            avatarUrl: avatarUrl,
            memberSinceText: "Member since \(formatter.string(from: memberSince))"
        )
    }
}
