import Foundation

struct PaginatedResult<T: Sendable>: Sendable {
    let items: [T]
    let hasNextPage: Bool
    let nextPage: Int?
}
