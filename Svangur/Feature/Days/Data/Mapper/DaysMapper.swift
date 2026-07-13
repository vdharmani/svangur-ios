import Foundation

extension DayItemDTO {
    func toDomain(currentDay: String) -> DayItem {
        DayItem(
            key: key,
            label: label,
            shortLabel: shortLabel ?? String(label.prefix(3)),
            isToday: key == currentDay
        )
    }
}
