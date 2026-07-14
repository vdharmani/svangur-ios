import Foundation

enum LegalDocumentType: Hashable, Sendable {
    case terms
    case privacy

    var title: String {
        switch self {
        case .terms:   return "Terms & Conditions"
        case .privacy: return "Privacy Policy"
        }
    }
}
