protocol GetRestaurantProfileUseCaseProtocol: Sendable {
    func execute() async throws(AppError) -> RestaurantEditData
}

final class GetRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol, Sendable {
    private let editRestaurantRepository: EditRestaurantRepositoryProtocol

    init(editRestaurantRepository: EditRestaurantRepositoryProtocol) {
        self.editRestaurantRepository = editRestaurantRepository
    }

    func execute() async throws(AppError) -> RestaurantEditData {
        try await editRestaurantRepository.getProfile()
    }
}
