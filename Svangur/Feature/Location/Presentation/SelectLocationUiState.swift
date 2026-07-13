import Foundation

enum SelectLocationUiState: Equatable {
    case idle
    case results([SelectLocationResultUi])
    case noResults(query: String)
}
