protocol UserRepositoryProtocol: Sendable {
    func getUser(id: String) async throws(AppError) -> User
}
