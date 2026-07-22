import Foundation

enum SearchUiState: Equatable {
    case idle
    case searching
    case noResults(query: String)
    case results([SearchResultUi])
    case error(message: String)
}
