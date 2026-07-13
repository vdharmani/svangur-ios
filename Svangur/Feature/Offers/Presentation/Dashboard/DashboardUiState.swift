import Foundation

enum DashboardUiState: Equatable {
    case idle
    case loading
    case loaded([OfferUi])
    case empty
    case error(String)
}
