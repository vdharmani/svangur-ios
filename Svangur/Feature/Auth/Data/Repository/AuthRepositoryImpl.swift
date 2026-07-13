import Foundation

final class AuthRepositoryImpl: AuthRepositoryProtocol, Sendable {
    static let tokenKey = "auth.token"
    static let rememberedCredentialsKey = "auth.remembered_credentials"

    private let apiClient: APIClientProtocol
    private let keychain: KeychainManagerProtocol

    init(apiClient: APIClientProtocol, keychain: KeychainManagerProtocol) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func login(credentials: Credentials) async throws(AppError) -> AuthToken {
        try await apiCall {
            let response: LoginResponseDTO = try await apiClient.execute(
                AuthEndpoint.login(
                    body: LoginRequestDTO(email: credentials.email, password: credentials.password),
                    idempotencyKey: UUID()
                )
            )
            let token = response.data.toDomain()
            try keychain.saveCodable(token.toCachedDTO(), key: Self.tokenKey)
            // Raw bearer token, read directly by `APIClient` to attach `Authorization` —
            // kept separate from the full `CachedAuthTokenDTO` so Core/Network doesn't need
            // to know about a Feature/Auth-owned type.
            if let tokenData = token.token.data(using: .utf8) {
                do {
                    try keychain.save(tokenData, key: BearerTokenKeychainKey.value)
                } catch {
                    #if DEBUG
                    print("⚠️ [Svangur] Failed to save bearer token to Keychain: \(error)")
                    #endif
                }
            } else {
                #if DEBUG
                print("⚠️ [Svangur] Bearer token was not valid UTF-8, not saved")
                #endif
            }
            return token
        }
    }

    func registerRestaurant(_ registration: RestaurantRegistration) async throws(AppError) {
        try await apiCall {
            var multipart = MultipartFormData()
            multipart.appendField(name: "name_en", value: registration.restaurantName)
            // Falls back to the English name when no Icelandic name is entered.
            multipart.appendField(
                name: "name_is",
                value: registration.restaurantNameIcelandic.isEmpty
                    ? registration.restaurantName
                    : registration.restaurantNameIcelandic
            )
            multipart.appendField(name: "email", value: registration.email)
            multipart.appendField(name: "password", value: registration.password)
            multipart.appendField(name: "confirm_password", value: registration.password)
            multipart.appendField(name: "phone", value: registration.phoneNumber)
            multipart.appendField(name: "description_en", value: registration.description)
            // Falls back to the English description when no Icelandic description is entered.
            multipart.appendField(
                name: "description_is",
                value: registration.descriptionIcelandic.isEmpty
                    ? registration.description
                    : registration.descriptionIcelandic
            )
            multipart.appendField(name: "address", value: registration.address)
            multipart.appendField(name: "city", value: registration.city)
            multipart.appendField(name: "country", value: registration.country)
            if let latitude = registration.latitude {
                multipart.appendField(name: "latitude", value: String(latitude))
            }
            if let longitude = registration.longitude {
                multipart.appendField(name: "longitude", value: String(longitude))
            }
            if let website = registration.website {
                multipart.appendField(name: "website", value: website)
            }
            multipart.appendField(name: "opening_hours", value: registration.openingHoursJSON())

            #if DEBUG
            Self.logRegisterParams(registration)
            #endif

            for (index, imageURL) in registration.imageRefs.enumerated() {
                guard let data = try? Data(contentsOf: imageURL) else { continue }
                multipart.appendFile(
                    name: "images",
                    filename: "image_\(index).jpg",
                    mimeType: "image/jpeg",
                    fileData: data
                )
            }
            if let documentURL = registration.documentRef, let documentData = try? Data(contentsOf: documentURL) {
                multipart.appendFile(
                    name: "document",
                    filename: documentURL.lastPathComponent,
                    mimeType: Self.documentMimeType(for: documentURL),
                    fileData: documentData
                )
            }

            // Verified live: `{ data: { owner_id, status } }` — status is always "pending"
            // on submit (admin approval required); not yet threaded to the UI.
            let _: RegisterResponseDTO = try await apiClient.execute(
                AuthEndpoint.register(body: multipart.build(), boundary: multipart.boundary)
            )
        }
    }

    func logout() async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(AuthEndpoint.logout)
        }
        try? keychain.delete(key: Self.tokenKey)
        try? keychain.delete(key: BearerTokenKeychainKey.value)
    }

    func requestPasswordReset(email: String) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(
                AuthEndpoint.requestPasswordReset(
                    body: PasswordResetRequestDTO(email: email),
                    idempotencyKey: UUID()
                )
            )
        }
    }

    func resetPassword(_ request: PasswordResetToken) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(
                AuthEndpoint.resetPassword(
                    body: PasswordResetConfirmDTO(token: request.token, newPassword: request.newPassword),
                    idempotencyKey: UUID()
                )
            )
        }
    }

    func reviseDocument(note: String, documentData: Data, filename: String) async throws(AppError) {
        try await apiCall {
            var multipart = MultipartFormData()
            multipart.appendField(name: "note", value: note)
            multipart.appendFile(
                name: "document",
                filename: filename,
                mimeType: Self.documentMimeType(for: URL(fileURLWithPath: filename)),
                fileData: documentData
            )
            let _: EmptyResponse = try await apiClient.execute(
                AuthEndpoint.reviseDocument(body: multipart.build(), boundary: multipart.boundary)
            )
        }
    }

    #if DEBUG
    private static func logRegisterParams(_ registration: RestaurantRegistration) {
        print("📝 [Svangur] /owner/register params:")
        print("   name_en: \(registration.restaurantName)")
        print("   name_is: \(registration.restaurantNameIcelandic.isEmpty ? registration.restaurantName : registration.restaurantNameIcelandic)")
        print("   email: \(registration.email)")
        print("   password: <redacted>")
        print("   confirm_password: <redacted>")
        print("   phone: \(registration.phoneNumber)")
        print("   description_en: \(registration.description)")
        print("   description_is: \(registration.descriptionIcelandic.isEmpty ? registration.description : registration.descriptionIcelandic)")
        print("   address: \(registration.address)")
        print("   city: \(registration.city)")
        print("   country: \(registration.country)")
        print("   latitude: \(registration.latitude.map { "\($0)" } ?? "<nil>")")
        print("   longitude: \(registration.longitude.map { "\($0)" } ?? "<nil>")")
        print("   website: \(registration.website ?? "<nil>")")
        print("   opening_hours: \(registration.openingHoursJSON())")
        print("   images: \(registration.imageRefs.count) file(s)")
        print("   document: \(registration.documentRef?.lastPathComponent ?? "<none>")")
    }
    #endif

    /// The server's `document` upload field rejects generic `application/octet-stream` (fails
    /// its file-type filter, surfacing confusingly as "Unexpected file field: document" rather
    /// than a clear MIME-type error) — verified live. Only `jpg`/`pdf` are accepted per the API.
    private static func documentMimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        default:
            return "application/octet-stream"
        }
    }

    func currentToken() async -> AuthToken? {
        keychain.readCodable(CachedAuthTokenDTO.self, key: Self.tokenKey)?.toDomain()
    }

    func rememberedCredentials() async -> Credentials? {
        keychain.readCodable(Credentials.self, key: Self.rememberedCredentialsKey)
    }

    func rememberCredentials(_ credentials: Credentials) async {
        try? keychain.saveCodable(credentials, key: Self.rememberedCredentialsKey)
    }

    func forgetRememberedCredentials() async {
        try? keychain.delete(key: Self.rememberedCredentialsKey)
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
