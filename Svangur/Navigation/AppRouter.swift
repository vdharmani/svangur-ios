import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    // MARK: - Deep Links

    func handle(_ url: URL) {
        guard let route = parseRoute(from: url) else { return }
        navigate(to: route)
    }

    private func parseRoute(from url: URL) -> AppRoute? {
        let components = url.pathComponents.filter { $0 != "/" }

        guard let first = components.first else { return nil }

        switch first {
        case "deals":
            if let idString = components.dropFirst().first,
               let id = Int64(idString) {
                return .dealDetail(dealId: id)
            }
            return .dealList

        case "restaurants":
            if let idString = components.dropFirst().first,
               let id = Int64(idString) {
                return .restaurantDetail(restaurantId: id)
            }
            return nil

        case "reset":
            // /reset?token=... or /reset/<token>
            let token = url.queryParameter("token")
                ?? components.dropFirst().first
                ?? ""
            return .resetPassword(token: token)

        case "dashboard":
            return .dashboard

        case "offers":
            if let idString = components.dropFirst().first,
               let id = Int64(idString) {
                return .offerDetail(offerId: id)
            }
            return .dashboard

        default:
            return nil
        }
    }
}

private extension URL {
    func queryParameter(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
