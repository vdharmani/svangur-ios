enum ProfileUiState: Equatable {
    case idle
    case loading
    case success(UserUi)
    case error(String)
}
