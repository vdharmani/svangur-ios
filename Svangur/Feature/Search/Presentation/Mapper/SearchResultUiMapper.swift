import Foundation

extension SearchOffer {
    func toUi() -> SearchResultUi {
        SearchResultUi(
            id: Int64(id) ?? 0,
            restaurantName: name,
            dealTitle: offer,
            distanceAndTime: [distanceKm, validDays]
                .filter { !$0.isEmpty }
                .joined(separator: " \u{2022} "),
            imageUrl: imageUrl.flatMap(URL.init(string:))
        )
    }
}
