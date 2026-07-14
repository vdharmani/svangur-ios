import Foundation

enum AppLanguage: String, Sendable, CaseIterable {
    case english = "en"
    case icelandic = "is"

    var displayLabel: String {
        switch self {
        case .english:   return "EN"
        case .icelandic: return "IS"
        }
    }

    var toggled: AppLanguage {
        self == .english ? .icelandic : .english
    }
}
