import Foundation

enum EditRestaurantUiState: Equatable {
    case loading
    case idle
    case saving
    case saved
    case error(String)
}
