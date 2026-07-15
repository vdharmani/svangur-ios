import SwiftUI

extension View {
    /// `.presentationCompactAdaptation(_:)` is iOS 16.4+ only — this project's deployment
    /// target is iOS 16.0, so below iOS 16.4 the popover falls back to the system's default
    /// compact-size-class adaptation (typically a sheet) rather than crashing.
    @ViewBuilder
    func svPopoverCompactAdaptation() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }
}
