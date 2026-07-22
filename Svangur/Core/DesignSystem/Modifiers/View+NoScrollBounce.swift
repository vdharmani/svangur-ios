import SwiftUI
import UIKit

extension View {
    /// Fully disables the rubber-band bounce on the nearest ancestor `ScrollView`, even
    /// when its content is taller than the viewport (`.scrollBounceBehavior(.basedOnSize)`
    /// only suppresses bounce when content fits, which isn't enough when content genuinely
    /// overflows but the top/bottom overscroll — and whatever it reveals behind the
    /// scroll view — still isn't wanted).
    func svNoScrollBounce() -> some View {
        background(ScrollBounceDisabler())
    }
}

private struct ScrollBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    // Re-applied on every SwiftUI update pass (not just once in `makeUIView`) — otherwise
    // a competing modifier like `.scrollBounceBehavior(.basedOnSize)` (which re-evaluates
    // and re-enables bounce whenever content overflows the viewport, as it always does here)
    // wins on the next layout pass and silently reverts this back to bouncy.
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var current = uiView.superview
            while let candidate = current {
                if let scrollView = candidate as? UIScrollView {
                    scrollView.bounces = false
                    break
                }
                current = candidate.superview
            }
        }
    }
}
