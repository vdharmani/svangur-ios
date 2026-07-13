import Foundation

struct RefreshDataDTO: Codable, Sendable {
    let token: String
}

struct RefreshResponseDTO: Codable, Sendable {
    let data: RefreshDataDTO
}
