import Foundation

enum ChangePasswordUiState: Equatable {
    case idle
    case submitting
    case success
    case error(String)
}
