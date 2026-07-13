import Foundation

/// Mirrors Android's `OpeningHourParam(day: String, start: String?, end: String?, isOpen: Boolean)`.
/// `day` is the lowercase 3-letter English abbreviation ("mon", "tue", ...), `start`/`end` are
/// "HH:mm" strings or nil. This is a plain domain value — the wire-shape (with the `is_open`
/// SerialName) is applied only at the data layer when building the multipart request.
struct OpeningHourParam: Sendable, Equatable {
    let day: String
    let start: String?
    let end: String?
    let isOpen: Bool
}
