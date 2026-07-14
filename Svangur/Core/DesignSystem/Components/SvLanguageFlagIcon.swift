import SwiftUI

/// Small flag glyph for the current `AppLanguage` — real asset for English (`ic_Uk`),
/// hand-drawn Nordic cross for Icelandic since no flag asset exists in the catalog yet.
struct SvLanguageFlagIcon: View {
    let language: AppLanguage

    var body: some View {
        switch language {
        case .english:
            Image("ic_Uk")
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .icelandic:
            IcelandicFlagShape()
        }
    }
}

private struct IcelandicFlagShape: View {
    private let blue = Color(red: 0.0, green: 0.22, blue: 0.59)
    private let red = Color(red: 0.84, green: 0.15, blue: 0.16)

    var body: some View {
        ZStack(alignment: .topLeading) {
            blue

            Color.white
                .frame(height: 4)
                .offset(y: 4)
            Color.white
                .frame(width: 6)
                .offset(x: 5)

            red
                .frame(height: 1.6)
                .offset(y: 5.2)
            red
                .frame(width: 2.4)
                .offset(x: 6.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }
}

#Preview("Language Flags") {
    HStack(spacing: 16) {
        SvLanguageFlagIcon(language: .english).frame(width: 19, height: 12)
        SvLanguageFlagIcon(language: .icelandic).frame(width: 19, height: 12)
    }
    .padding()
}
