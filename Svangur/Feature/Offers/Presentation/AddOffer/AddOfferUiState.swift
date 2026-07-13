import Foundation

enum AddOfferLoadState: Equatable {
    case ready
    case loadingExisting
    case saving
    case error(String)
}

enum AddOfferUiEffect: Equatable {
    // NOTE: no associated `offerId` anymore — Android's create/update repository calls both
    // return `Unit` (see `OfferRepositoryProtocol.createOffer`/`updateOffer`), so the freshly
    // saved offer's ID isn't available here. `AddOfferScreen` never read the ID from this case
    // anyway (it only pattern-matches `.saved` to navigate back to the dashboard).
    case saved
    case dismissed
    case showAlert(title: String, message: String)
}
