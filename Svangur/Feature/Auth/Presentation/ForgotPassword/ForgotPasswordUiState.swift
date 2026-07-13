import Foundation

enum ForgotPasswordUiState: Equatable {
    case idle
    case submitting
    case sent
    case error(String)
}
