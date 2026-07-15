import Foundation

enum SelectLocationUiState: Equatable {
    case idle
    case searching
    case results([SelectLocationResultUi])
    case noResults(query: String)
    case error(message: String)
}
