import Foundation

extension SearchOfferDTO {
    func toDomain() -> SearchOffer {
        let distance: String
        if let distanceKm = restaurant?.distanceKm {
            distance = String(format: "%.1f km", distanceKm)
        } else {
            distance = ""
        }

        return SearchOffer(
            id: String(offerId),
            name: restaurant?.name ?? "",
            offer: title,
            badge: discountLabel ?? "",
            distanceKm: distance,
            validDays: formatValidDays(validDays, validTimeStart: validTimeStart, validTimeEnd: validTimeEnd),
            imageUrl: imageUrl ?? images.first?.url
        )
    }
}

// MARK: - Valid Days Formatting

private let dayOrder = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

private let dayDisplay: [String: String] = [
    "mon": "Mon",
    "tue": "Tue",
    "wed": "Wed",
    "thu": "Thu",
    "fri": "Fri",
    "sat": "Sat",
    "sun": "Sun",
]

private func formatValidDays(_ validDays: [String], validTimeStart: String?, validTimeEnd: String?) -> String {
    let sortedDays = validDays.sorted { lhs, rhs in
        let lhsIndex = dayOrder.firstIndex(of: lhs.lowercased()) ?? Int.max
        let rhsIndex = dayOrder.firstIndex(of: rhs.lowercased()) ?? Int.max
        return lhsIndex < rhsIndex
    }

    let dayRange: String
    if sortedDays.isEmpty {
        dayRange = ""
    } else if sortedDays.count == 1 {
        dayRange = displayName(for: sortedDays[0])
    } else {
        dayRange = "\(displayName(for: sortedDays[0])) - \(displayName(for: sortedDays[sortedDays.count - 1]))"
    }

    let timeRange: String
    if let start = validTimeStart, let end = validTimeEnd,
       !start.trimmingCharacters(in: .whitespaces).isEmpty,
       !end.trimmingCharacters(in: .whitespaces).isEmpty {
        timeRange = " \(hhmm(from: start)) - \(hhmm(from: end))"
    } else {
        timeRange = ""
    }

    return dayRange + timeRange
}

private func displayName(for code: String) -> String {
    dayDisplay[code.lowercased()] ?? code
}

private func hhmm(from time: String) -> String {
    let components = time.split(separator: ":")
    guard components.count >= 2 else { return time }
    return "\(components[0]):\(components[1])"
}
