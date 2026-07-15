import SwiftUI
import Combine

@MainActor
final class LanguageService: ObservableObject {
    @Published private(set) var current: AppLanguage = .english

    func toggle() {
        current = current.toggled
    }
}
