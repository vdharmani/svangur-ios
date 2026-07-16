import SwiftUI

extension View {
    /// Animated shimmer sweep for skeleton / loading placeholders.
    /// Apply on top of a `Color.svShimmer` fill. When Reduce Motion is on,
    /// the static placeholder fill is kept and only the sweep is disabled.
    func svShimmer() -> some View {
        modifier(SvShimmerModifier())
    }
}

private struct SvShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: isAnimating ? proxy.size.width : -proxy.size.width * 0.6)
                    }
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Previews

#Preview("Shimmer - Image placeholder") {
    Rectangle()
        .fill(Color.svShimmer)
        .svShimmer()
        .frame(width: 130, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .padding()
}

#Preview("Shimmer - Text line") {
    RoundedRectangle(cornerRadius: SvSpacing.xs)
        .fill(Color.svShimmer)
        .svShimmer()
        .frame(width: 200, height: 14)
        .padding()
}
