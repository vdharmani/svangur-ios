import Foundation

struct DayItem: Sendable, Equatable {
    let key: String
    let label: String
    let shortLabel: String
    let isToday: Bool
}
