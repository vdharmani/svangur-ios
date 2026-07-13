import Foundation

nonisolated struct TimeOfDay: Sendable, Equatable, Hashable, Comparable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    static let startOfDay = TimeOfDay(hour: 0, minute: 0)
    static let endOfDay = TimeOfDay(hour: 23, minute: 59)

    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

nonisolated extension TimeOfDay {
    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        self.init(hour: h, minute: m)
    }

    var formatted24h: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
