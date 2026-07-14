import SwiftUI

struct SettingsScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(UserSession.self) private var session
    @State var viewModel: SettingsViewModel
    @State private var showLogoutConfirmation = false
    @State private var showDeleteConfirmation = false

    init(viewModel: SettingsViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }
    
    @ViewBuilder
    private func compactLayout() -> some View {
        VStack(spacing: 0) {
            customHeader
            ScrollView {
                VStack(spacing: SvSpacing.xl) {
                    restaurantCard
                    generalSection
                    accountSection
                    Spacer(minLength: SvSpacing.xxl)
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.md)
            }
        }
        .background(Color.svBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
        .blur(radius: (showLogoutConfirmation || showDeleteConfirmation) ? 2 : 0)
        .animation(.easeInOut(duration: 0.2), value: showLogoutConfirmation)
        .animation(.easeInOut(duration: 0.2), value: showDeleteConfirmation)
        .overlay {
            if showLogoutConfirmation {
                SvConfirmationDialog(
                    iconName: "LogoutBG",
                    title: "Logout Account",
                    message: "Are you sure you want to logout this account?",
                    primaryTitle: "Cancel",
                    secondaryTitle: "Logout",
                    onPrimary: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLogoutConfirmation = false
                        }
                    },
                    onSecondary: {
                        showLogoutConfirmation = false
                        Task {
                            await viewModel.logout()
                            session.clear()
                            router.popToRoot()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showDeleteConfirmation {
                SvConfirmationDialog(
                    iconName: "DeleteAccountBG",
                    title: "Delete Account",
                    message: "Are you sure you want to delete this account?",
                    primaryTitle: "Cancel",
                    secondaryTitle: "Delete",
                    onPrimary: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirmation = false
                        }
                    },
                    onSecondary: {
                        showDeleteConfirmation = false
                        // TODO: wire to viewModel.deleteAccount() when the use case is added
                    }
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Header
    private var customHeader: some View {
        HStack(spacing: SvSpacing.sm) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 15, height: 44, alignment: .leading)
            }
            .accessibilityLabel("Back")
            
            Text("Settings")
                .font(SvFont.titleSmall)
                .foregroundStyle(Color.svOnBackground)
            
            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
    }
    
    // MARK: - Restaurant Card
    private var restaurantCard: some View {
        HStack(spacing: SvSpacing.lg) {
            restaurantAvatar
                .frame(width: 56, height: 56)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: SvSpacing.xxs) {
                Text(viewModel.profile?.name ?? "Restaurant Name")
                    .font(SvFont.titleMedium)
                    .foregroundStyle(Color.svOnBackground)
                    .redacted(reason: viewModel.profile == nil ? .placeholder : [])
                
                Button {
                    router.navigate(to: .editRestaurant)
                } label: {
                    HStack(spacing: SvSpacing.xxs) {
                        Text("Edit restaurant")
                            .font(SvFont.editLink)
                            .foregroundStyle(Color.svPrimary)
                        Image("EditIconForward")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                    }
                    .foregroundStyle(Color.svPrimary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(SvSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                    .fill(Color.svFieldBackground)
                Image("SettingsBGImage")
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
            }
        )
    }

    @ViewBuilder
    private var restaurantAvatar: some View {
        if let url = viewModel.profile?.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.svShimmer)
            }
        } else if viewModel.profile == nil {
            // Still loading — shimmer instead of the bundled fallback avatar, so the real photo
            // doesn't visibly replace a different-looking placeholder image once it arrives.
            Circle().fill(Color.svShimmer).redacted(reason: .placeholder)
        } else {
            // Profile loaded and confirmed to have no restaurant photo.
            Image("SampleRestaurantAvatar").resizable().scaledToFill()
        }
    }
    // MARK: - General Section
    
    private var generalSection: some View {
        sectionCard(label: "General") {
            settingsRow(
                icon: "Terms&Conditions",
                title: "Terms & Conditions"
            ) {
                router.navigate(to: .legal(documentType: .terms))
            }

            Divider()
                .background(Color.svDivider)
                .padding(.leading, SvSpacing.lg + 22 + SvSpacing.md)

            settingsRow(
                icon: "PrivacyPolicy",
                title: "Privacy Policy"
            ) {
                router.navigate(to: .legal(documentType: .privacy))
            }
        }
    }
    // MARK: - Account Section
    
    private var accountSection: some View {
        sectionCard(label: "Account") {
            settingsRow(
                icon: "lock.fill",
                title: "Change Password",
                isSystemIcon: true
            ) {
                router.navigate(to: .changePassword)
            }

            Divider()
                .background(Color.svDivider)
                .padding(.leading, SvSpacing.lg + 22 + SvSpacing.md)

            settingsRow(
                icon: "DeleteAccount",
                title: "Delete Account"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = true
                }
            }
            
            Divider()
                .background(Color.svDivider)
                .padding(.leading, SvSpacing.lg + 22 + SvSpacing.md)
            
            settingsRow(
                icon: "LogOut",
                title: "Log Out"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLogoutConfirmation = true
                }
            }
        }
    }
    
    // MARK: - Section card primitive

    private func sectionCard<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(SvFont.sectionLabel)
                .foregroundStyle(Color.svOnBackground)
                .padding(.horizontal, SvSpacing.lg)
                .padding(.top, SvSpacing.md)
                .padding(.bottom, SvSpacing.xs)
            content()
                .padding(.bottom, SvSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .shadow(color: .black.opacity(0.1),
                radius: 4,
                x: 0,
                y: 0)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [.svPrimaryGradientStart, .svPrimaryGradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 13)
                .offset(x: 0, y: 18)
        }
    }
    // MARK: - Settings row
    private func settingsRow(
        icon: String,
        title: LocalizedStringKey,
        isSystemIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SvSpacing.md) {
                Group {
                    if isSystemIcon {
                        Image(systemName: icon).resizable()
                    } else {
                        Image(icon).resizable()
                    }
                }
                .scaledToFit()
                .foregroundStyle(Color.svOnBackground)
                .frame(width: 20, height: 22)
                Text(title)
                    .font(SvFont.body)
                    .foregroundStyle(Color.svOnBackground)
                Spacer()
            }
            .padding(.horizontal, SvSpacing.lg)
            .padding(.vertical, SvSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Previews
    
    #Preview("Settings - Default") {
        NavigationStack {
            SettingsScreen(viewModel: .previewInstance())
        }
        .environment(AppRouter())
        .environment(UserSession(authRepository: MockAuthRepository()))
    }
}
