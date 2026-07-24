import Foundation

enum Weekday: Int, Sendable, Equatable, CaseIterable, Identifiable, Comparable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var shortNameKey: String {
        "weekday_short_\(rawValue)"
    }

    var shortName: String {
        switch self {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
        }
    }

    var fullName: String {
        switch self {
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        case .sunday:    return "Sunday"
        }
    }
}

// MARK: - Wire day codes ("mon"..."sun")

/// Matches Android's `DAY_CODES = ["mon","tue","wed","thu","fri","sat","sun"]` (Mon = index 0).
/// The backend's `valid_days` field is a JSON array of these lowercase 3-letter codes.
extension Weekday {
    private static let dayCodes: [String] = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    init?(dayCode: String) {
        guard let index = Weekday.dayCodes.firstIndex(of: dayCode) else { return nil }
        self.init(rawValue: index + 1)
    }

    var dayCode: String {
        Weekday.dayCodes[rawValue - 1]
    }
}
