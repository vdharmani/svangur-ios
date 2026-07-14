import SwiftUI

@MainActor
@Observable
final class LanguageService {
    private(set) var current: AppLanguage = .english

    func toggle() {
        current = current.toggled
    }
}
