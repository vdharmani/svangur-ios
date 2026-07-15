import SwiftUI

extension View {
    /// `.sensoryFeedback(.success, trigger:)` is iOS 17+ only — this project's deployment
    /// target is iOS 16, so below iOS 17 the feedback is silently skipped rather than crashing.
    @ViewBuilder
    func svSuccessFeedback(trigger: some Equatable) -> some View {
        if #available(iOS 17, *) {
            self.sensoryFeedback(.success, trigger: trigger)
        } else {
            self
        }
    }
}
