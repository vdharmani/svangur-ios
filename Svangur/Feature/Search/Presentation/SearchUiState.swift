import Foundation

enum SearchUiState: Equatable {
    case idle
    case noResults(query: String)
    case results([SearchResultUi])
}
