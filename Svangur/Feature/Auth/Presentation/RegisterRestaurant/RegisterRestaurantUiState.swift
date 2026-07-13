import Foundation

enum RegisterRestaurantUiState: Equatable {
    case idle
    case submitting
    case submitted
    case error(String)
}
