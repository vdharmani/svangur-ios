import SwiftUI

struct SvLogoMark: View {
    var size: CGFloat = 56
    var foreground: Color = .svOnPrimary

    var body: some View {
        Text("Sv\u{00C5}ngur")
            .font(.system(size: size, weight: .bold, design: .default))
            .tracking(-1)
            .foregroundStyle(foreground)
            .accessibilityLabel("Svangur")
    }
}

#Preview("Logo") {
    VStack(spacing: 32) {
        SvLogoMark()
            .padding(40)
            .background(Color.svPrimary)
        SvLogoMark(foreground: .svPrimary)
            .padding(40)
            .background(Color.svBackground)
    }
}
