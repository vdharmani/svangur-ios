import Foundation

enum OfferDetailUiState: Equatable {
    case idle
    case loading
    case loaded(OfferUi)
    case deleted
    case error(String)
}
