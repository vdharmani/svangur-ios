enum DealDetailUiState: Equatable {
    case idle
    case loading
    case loaded(DealDetailUi)
    case error(String)
}
