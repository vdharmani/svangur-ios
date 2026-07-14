protocol RegisterRestaurantUseCaseProtocol: Sendable {
    func execute(_ registration: RestaurantRegistration) async throws(AppError)
}

final class RegisterRestaurantUseCase: RegisterRestaurantUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.authRepository = authRepository
        self.validate = validate
    }

    func execute(_ registration: RestaurantRegistration) async throws(AppError) {
        let result = validate.validateRegistration(
            RegistrationValidationInput(
                restaurantName: registration.restaurantName,
                restaurantNameIcelandic: registration.restaurantNameIcelandic,
                email: registration.email,
                password: registration.password,
                // The ViewModel already confirmed the passwords match before building this
                // domain model, which doesn't carry the raw confirm-password value.
                confirmPassword: registration.password,
                phoneNumber: registration.phoneNumber,
                description: registration.description,
                descriptionIcelandic: registration.descriptionIcelandic,
                address: registration.address,
                city: registration.city,
                imageCount: registration.imageRefs.count,
                hasDocument: registration.documentRef != nil
            )
        )
        guard result.isValid else {
            throw .validation(message: "Please fix the errors in the form before continuing.")
        }
        try await authRepository.registerRestaurant(registration)
    }
}
