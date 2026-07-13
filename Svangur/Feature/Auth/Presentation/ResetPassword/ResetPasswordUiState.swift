import Foundation

enum ResetPasswordUiState: Equatable {
    case idle
    case submitting
    case success
    case error(String)
}
