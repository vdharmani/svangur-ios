import Foundation

enum LoginLoadState: Equatable {
    case ready
    case submitting
    case error(String)
}

enum LoginUiEffect: Equatable {
    case loggedIn(AuthToken)
}
