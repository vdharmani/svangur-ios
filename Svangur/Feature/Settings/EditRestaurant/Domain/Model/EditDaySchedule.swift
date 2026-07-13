import Foundation

/// Mirrors Android's `EditDaySchedule(day: DayOfWeek, openTime: LocalTime, closeTime: LocalTime, isClosed: Boolean)`.
/// `openTime`/`closeTime` are represented as plain "HH:mm" strings — iOS has no direct `LocalTime`
/// equivalent, and introducing a time-value-object here would be inventing scope beyond this port.
struct EditDaySchedule: Sendable, Equatable {
    let day: Weekday
    let openTime: String
    let closeTime: String
    let isClosed: Bool

    init(day: Weekday, openTime: String = "09:00", closeTime: String = "22:00", isClosed: Bool = false) {
        self.day = day
        self.openTime = openTime
        self.closeTime = closeTime
        self.isClosed = isClosed
    }
}
