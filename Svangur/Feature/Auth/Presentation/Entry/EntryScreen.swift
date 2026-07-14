import SwiftUI

struct EntryScreen: View {
    let onLogin: () -> Void
    let onSignup: () -> Void
    
    var body: some View {
        // The action card lives in the main VStack flow (NOT in .overlay) so
        // SwiftUI computes a real gap between the tagline and the card —
        // overlays are layered above and won't push siblings out of the way.
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: proxy.size.height * 0.08)
                
                Image(.svangurWordmark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: min(proxy.size.width * 0.62, 280))
                
                Spacer().frame(height: SvSpacing.xl)
                
                Text("Grow your restaurant by sharing exclusive dining offers.")
                    .font(taglineFont(for: proxy.size.width))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, max(proxy.size.width * 0.09, 24))
                
                // Flexible gap between tagline and action card.
                // minLength guarantees at least 32pt; the Spacer absorbs any
                // remaining vertical space on tall phones.
                Spacer(minLength: SvSpacing.xxxl)
                
                actionCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, SvSpacing.lg)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Background extends beyond safe area — photo + 55% black scrim
        // continue underneath the home-indicator area.
        .background {
            GeometryReader { proxy in
                ZStack {
                    Image(.entryBackground)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width,
                               height: proxy.size.height)
                        .clipped()

                    Color.black.opacity(0.55)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Tagline font scales mildly with screen width
    
    private func taglineFont(for width: CGFloat) -> Font {
        // 24pt at 375pt-wide phones, 28pt at the 428pt Figma baseline,
        // capped to 30pt on big phones / iPad.
        let baseSize = (24 + (width - 375) * (4.0 / 53.0))
            .clamped(to: 22...30)
        return Font.custom("Poppins-Regular", size: baseSize, relativeTo: .title2)
    }
    
    // MARK: - Action card
    
    private var actionCard: some View {
        VStack(spacing: SvSpacing.lg) {
            SvPrimaryButton(title: "Register Restaurant", action: onSignup)
            
            Button(action: onLogin) {
                Text("Login")
                    .font(SvFont.buttonLabel)
                    .foregroundStyle(Color.svPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: SvSpacing.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                            .fill(Color.svPrimary.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                            .stroke(Color.svPrimary.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Text("By registering, you agree to our \(Text("Terms of use").bold()) and \(Text("Privacy policy").bold()).")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svOnBackground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, SvSpacing.xs)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.svBackground)
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview("Entry — iPhone SE 3") {
    EntryScreen(onLogin: {}, onSignup: {})
        .frame(width: 375, height: 667)
}

#Preview("Entry — iPhone 15") {
    EntryScreen(onLogin: {}, onSignup: {})
        .frame(width: 393, height: 852)
}

#Preview("Entry — iPhone 15 Pro Max") {
    EntryScreen(onLogin: {}, onSignup: {})
        .frame(width: 430, height: 932)
}

#Preview("Entry — iPad") {
    EntryScreen(onLogin: {}, onSignup: {})
        .frame(width: 820, height: 1180)
}
