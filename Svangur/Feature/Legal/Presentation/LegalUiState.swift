import Foundation

enum LegalUiState: Equatable {
    case idle
    case loading
    case loaded(html: String)
    case error(String)
}
