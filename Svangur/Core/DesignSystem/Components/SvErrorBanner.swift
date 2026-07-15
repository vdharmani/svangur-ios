import SwiftUI

/// A transient banner for surfacing server/API errors (e.g. a failed login, a failed save) —
/// distinct from per-field validation errors, which stay inline under each field. Only use this
/// where the underlying content/form is still visible behind it (a failed *action*), not for an
/// initial content load that has nothing else to show — those keep their dedicated full-screen
/// empty/retry state instead.
struct SvErrorBanner: View {
    let message: String?

    @ViewBuilder
    var body: some View {
        if let message {
            Text(message)
                .font(SvFont.captionStrong)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SvSpacing.lg)
                .padding(.vertical, SvSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius, style: .continuous)
                        .fill(Color.svPrimaryPressed)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, SvSpacing.screenPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Owns the show/auto-dismiss timing for `SvErrorBanner` — a `ViewModifier` (not a plain
/// function) specifically so it can hold `@State`: the banner auto-dismisses itself 2 seconds
/// after a new message arrives, independent of whether the underlying error state is ever
/// cleared by the caller.
private struct ErrorBannerModifier: ViewModifier {
    let message: String?
    let topPadding: CGFloat

    @State private var visibleMessage: String?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                SvErrorBanner(message: visibleMessage)
                    .padding(.top, topPadding)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleMessage)
            // Single-argument `.onChange(of:perform:)` — the two-argument (old, new) overload is
            // iOS 17+ only; this project's deployment target is iOS 16.
            .onChange(of: message) { newMessage in
                dismissTask?.cancel()
                visibleMessage = newMessage
                guard newMessage != nil else { return }
                dismissTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    visibleMessage = nil
                }
            }
            .onAppear { visibleMessage = message }
    }
}

extension View {
    /// Overlays `SvErrorBanner(message:)` at the top of this view — auto-dismisses 2 seconds
    /// after each new message. For screens with their own colored header (e.g. a curved pink
    /// header, like Login), overlay `SvErrorBanner` directly on that header instead of using
    /// this modifier, so the banner sits within the header rather than at the very top of the
    /// screen.
    func svErrorBanner(_ message: String?, topPadding: CGFloat = SvSpacing.sm) -> some View {
        modifier(ErrorBannerModifier(message: message, topPadding: topPadding))
    }
}

#Preview("SvErrorBanner") {
    VStack {
        SvErrorBanner(message: "Invalid email or password")
        Spacer()
    }
    .padding(.top, 40)
    .background(Color.svBackground)
}
