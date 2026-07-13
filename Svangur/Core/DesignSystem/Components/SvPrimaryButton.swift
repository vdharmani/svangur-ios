import SwiftUI

struct SvPrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.svOnPrimary)
                } else {
                    Text(title)
                        .font(SvFont.buttonLabel)
                        .foregroundStyle(Color.svOnPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: SvSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                    .fill(SvBrandGradient.button)
            )
            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 3)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

enum SvBrandGradient {
    // linear-gradient(168.35deg, #FAA5B6 1.79%, #F06285 87.86%)
    static let button = LinearGradient(
        stops: [
            .init(color: .svPrimaryGradientStart, location: 0.0179),
            .init(color: .svPrimaryGradientEnd,   location: 0.8786)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct SvSecondaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SvFont.buttonLabel)
                .foregroundStyle(isEnabled ? Color.svPrimary : Color.svSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: SvSpacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                        .stroke(isEnabled ? Color.svPrimary : Color.svDivider, lineWidth: 1.5)
                )
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        SvPrimaryButton(title: "Log In", action: {})
        SvPrimaryButton(title: "Saving…", isLoading: true, action: {})
        SvPrimaryButton(title: "Disabled", isEnabled: false, action: {})
        SvSecondaryButton(title: "Cancel", action: {})
    }
    .padding(SvSpacing.screenPadding)
    .background(Color.svBackground)
}
