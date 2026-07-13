import SwiftUI

struct SplashScreen: View {
    let onFinished: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            SvBrandGradient.button
                .ignoresSafeArea()
            Image(.svangurWordmark)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 220)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.9)
                .animation(.easeOut(duration: 0.4), value: hasAppeared)
        }
        .task {
            hasAppeared = true
            try? await Task.sleep(for: .milliseconds(900))
            onFinished()
        }
    }
}

#Preview("Splash") {
    SplashScreen(onFinished: {})
}
