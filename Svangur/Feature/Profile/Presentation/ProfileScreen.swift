import SwiftUI

struct ProfileScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    @ViewBuilder
    private func compactLayout() -> some View {
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear

            case .loading:
                ProgressView("Loading profile...")

            case .success(let user):
                ProfileContent(user: user)

            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(message)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.onAppear() }
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.onAppear() }
    }
}

// MARK: - Content Subview

private struct ProfileContent: View {
    let user: UserUi

    var body: some View {
        VStack(spacing: 24) {
            AsyncImage(url: user.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())

            VStack(spacing: 8) {
                Text(user.displayName)
                    .font(.title2.bold())

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(user.memberSinceText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.top, 40)
    }
}

// MARK: - Previews

private let previewUser = UserUi(
    id: "1",
    displayName: "Gurdeep Singh",
    email: "gurdeep@svangur.is",
    avatarUrl: nil,
    memberSinceText: "Member since Nov 2023"
)

#Preview("Profile - Idle") {
    NavigationStack {
        ProfileScreen(viewModel: .previewInstance(state: .idle))
    }
}

#Preview("Profile - Loading") {
    NavigationStack {
        ProfileScreen(viewModel: .previewInstance(state: .loading))
    }
}

#Preview("Profile - Success") {
    NavigationStack {
        ProfileScreen(viewModel: .previewInstance(state: .success(previewUser)))
    }
}

#Preview("Profile - Error") {
    NavigationStack {
        ProfileScreen(viewModel: .previewInstance(state: .error("Network error")))
    }
}

#Preview("Profile - Wide (no break)") {
    NavigationStack {
        ProfileScreen(viewModel: .previewInstance(state: .success(previewUser)))
            .frame(width: 1024, height: 1366)
    }
}
