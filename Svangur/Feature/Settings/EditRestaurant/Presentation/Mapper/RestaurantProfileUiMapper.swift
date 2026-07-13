import Foundation

extension RestaurantEditData {
    func toProfileUi() -> RestaurantProfileUi {
        RestaurantProfileUi(
            name: nameEn.isEmpty ? nameIs : nameEn,
            description: descriptionEn.isEmpty ? descriptionIs : descriptionEn,
            imageURL: restaurantImages.first.flatMap(URL.init(string:))
        )
    }
}
