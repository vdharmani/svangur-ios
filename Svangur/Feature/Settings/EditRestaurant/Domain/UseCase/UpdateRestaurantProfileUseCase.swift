protocol UpdateRestaurantProfileUseCaseProtocol: Sendable {
    func execute(params: ProfileUpdateParams) async throws(AppError)
}

final class UpdateRestaurantProfileUseCase: UpdateRestaurantProfileUseCaseProtocol, Sendable {
    private let editRestaurantRepository: EditRestaurantRepositoryProtocol

    init(editRestaurantRepository: EditRestaurantRepositoryProtocol) {
        self.editRestaurantRepository = editRestaurantRepository
    }

    func execute(params: ProfileUpdateParams) async throws(AppError) {
        try await editRestaurantRepository.updateProfile(params: params)
    }
}
