import SwiftUI

struct PhotoSourcePickerSheet: View {
    var showCameraOption: Bool = true
    let onTakePhoto: () -> Void
    let onChooseFromGallery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            VStack(alignment: .leading, spacing: SvSpacing.xxs) {
                Text("Add photo")
                    .font(SvFont.title)
                    .foregroundStyle(Color.svOnBackground)
                Text("Choose how you'd like to add a photo")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)
            }

            VStack(spacing: SvSpacing.md) {
                if showCameraOption {
                    PhotoSourceRow(
                        systemImage: "camera.fill",
                        title: "Take photo",
                        subtitle: "Use your camera",
                        action: onTakePhoto
                    )
                }
                PhotoSourceRow(
                    systemImage: "photo.fill",
                    title: "Choose from gallery",
                    subtitle: "Pick from your photos",
                    action: onChooseFromGallery
                )
            }
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.xl)
        .padding(.bottom, SvSpacing.xl)
    }
}

private struct PhotoSourceRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SvSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.svPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.svPrimarySurfaceStrong, in: Circle())

                VStack(alignment: .leading, spacing: SvSpacing.xxs) {
                    Text(title)
                        .font(SvFont.mainLabel)
                        .foregroundStyle(Color.svOnBackground)
                    Text(subtitle)
                        .font(SvFont.bodySmall)
                        .foregroundStyle(Color.svSecondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.svPrimary)
            }
            .padding(SvSpacing.md)
            .background(Color.svPrimarySurface, in: RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview("Photo source sheet") {
    Color.svBackground
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PhotoSourcePickerSheet(onTakePhoto: {}, onChooseFromGallery: {})
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .svPresentationCornerRadius(24)
        }
}

#Preview("Photo source sheet - Dark") {
    Color.svBackground
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PhotoSourcePickerSheet(onTakePhoto: {}, onChooseFromGallery: {})
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .svPresentationCornerRadius(24)
        }
        .preferredColorScheme(.dark)
}
