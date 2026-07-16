import SwiftUI

extension View {
    /// `.presentationCornerRadius(_:)` is iOS 16.4+ only — this project's deployment
    /// target is iOS 16.0, so below iOS 16.4 the sheet falls back to the system's
    /// default corner radius rather than crashing.
    @ViewBuilder
    func svPresentationCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }
}
