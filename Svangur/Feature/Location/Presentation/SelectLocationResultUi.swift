import Foundation

struct SelectLocationResultUi: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String

    /// The place name shown as the row's first line — the segment before the first comma
    /// of the Places description (e.g. "Testour" from "Testour, Tunisia").
    var title: String {
        displayName.split(separator: ",", maxSplits: 1)
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? displayName
    }

    /// The locality/region detail shown as the row's second line — everything after the
    /// first comma (e.g. "Tunisia"). Empty when the description has no comma.
    var subtitle: String {
        let parts = displayName.split(separator: ",", maxSplits: 1)
        guard parts.count == 2 else { return "" }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }
}
