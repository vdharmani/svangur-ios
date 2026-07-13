import SwiftUI

struct SvConfirmationDialog: View {
    let iconName: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let secondaryTitle: LocalizedStringKey?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    init(
        iconName: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        primaryTitle: LocalizedStringKey,
        secondaryTitle: LocalizedStringKey? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { (onSecondary ?? onPrimary)() }

            card
                .padding(.horizontal, 32)
        }
    }

    private var card: some View {
        VStack(spacing: SvSpacing.md) {
            Spacer().frame(height: 0)
            Text(title)
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)

            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SvSpacing.lg)

            buttonRow
                .padding(.top, SvSpacing.md)
                .padding(.bottom, SvSpacing.md)
        }
        .padding(.horizontal, SvSpacing.lg)
        .padding(.top, 60)
        .padding(.bottom, SvSpacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .top) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 85, height: 85)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
                .offset(y: -32)
        }
    }

    @ViewBuilder
    private var buttonRow: some View {
        if let secondaryTitle, let onSecondary {
            HStack(spacing: SvSpacing.md) {
                SvPrimaryButton(title: primaryTitle, action: onPrimary)

                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(SvFont.buttonLabel)
                        .foregroundStyle(Color.svOnBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: SvSpacing.buttonHeight)
                        .background(
                            Color.svFieldBackground,
                            in: RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                        )
                }
                .buttonStyle(.plain)
            }
        } else {
            SvPrimaryButton(title: primaryTitle, action: onPrimary)
                .padding(.horizontal, SvSpacing.xl)
        }
    }
}

#Preview("Two-button dialog") {
    Color.svBackground
        .overlay {
            SvConfirmationDialog(
                iconName: "power",
                title: "Logout Account",
                message: "Are you sure you want to logout this account?",
                primaryTitle: "Cancel",
                secondaryTitle: "Logout",
                onPrimary: {},
                onSecondary: {}
            )
        }
}

#Preview("Single-button dialog") {
    Color.svBackground
        .overlay {
            SvConfirmationDialog(
                iconName: "checkmark",
                title: "Registration Submitted",
                message: "Your restaurant details have been sent to our admin team. Upon approval, your deals will be listed on the platform.",
                primaryTitle: "Back to Home",
                onPrimary: {}
            )
        }
}
