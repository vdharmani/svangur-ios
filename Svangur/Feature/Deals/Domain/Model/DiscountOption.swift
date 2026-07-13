import Foundation

/// A consumer-facing discount filter chip (e.g. "20%+", "2 for 1").
struct DiscountUserFilter: Sendable, Equatable {
    let id: Int
    let key: String
    let label: String
}

/// A discount value an owner can set on an offer (e.g. "30% off", "2 for 1", "Custom Offer").
struct DiscountOwnerOption: Sendable, Equatable {
    let id: Int
    let value: String
    let kind: String
    let label: String
}
