import Foundation

enum AddOfferMode: Equatable, Sendable {
    case create
    case edit(offerId: Int64)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
