import Foundation

enum HomeUiState: Equatable {
    case idle
    case loading
    case loaded([DealCardUi])
    case empty
    case error(String)
}
