import Foundation

struct CredentialsValidation: Sendable, Equatable {
    var email: ValidationError?
    var password: ValidationError?

    var isValid: Bool { email == nil && password == nil }
}

protocol ValidateCredentialsUseCaseProtocol: Sendable {
    func validateLogin(email: String, password: String) -> CredentialsValidation
    func validateRegistration(_ input: RegistrationValidationInput) -> RegistrationValidation
    func validateNewPassword(_ password: String, confirm: String) -> NewPasswordValidation
    func validateChangePassword(current: String, new: String, confirm: String) -> ChangePasswordValidation
    func validateEmailFormat(_ email: String) -> ValidationError?
    func validatePhoneNumber(_ phone: String) -> ValidationError?
}

struct RegistrationValidationInput: Sendable, Equatable {
    let restaurantName: String
    let restaurantNameIcelandic: String
    let email: String
    let password: String
    let confirmPassword: String
    let phoneNumber: String
    let description: String
    let descriptionIcelandic: String
    let address: String
    let city: String
    let imageCount: Int
    let hasDocument: Bool
}

struct RegistrationValidation: Sendable, Equatable {
    var restaurantName: ValidationError?
    var restaurantNameIcelandic: ValidationError?
    var email: ValidationError?
    var password: ValidationError?
    var confirmPassword: ValidationError?
    var phoneNumber: ValidationError?
    var description: ValidationError?
    var descriptionIcelandic: ValidationError?
    var address: ValidationError?
    var city: ValidationError?
    var images: ValidationError?
    var document: ValidationError?

    // `city` isn't user-editable (only ever auto-filled, best-effort, from device location in
    // `RegisterRestaurantViewModel.onAppear()`) — it must not block submission if that fill
    // never happened, since there's no field the user could use to fix it.
    var isValid: Bool {
        restaurantName == nil && restaurantNameIcelandic == nil && email == nil &&
        password == nil && confirmPassword == nil &&
        phoneNumber == nil && description == nil && descriptionIcelandic == nil &&
        address == nil &&
        images == nil && document == nil
    }
}

struct NewPasswordValidation: Sendable, Equatable {
    var password: ValidationError?
    var confirm: ValidationError?

    var isValid: Bool { password == nil && confirm == nil }
}

struct ChangePasswordValidation: Sendable, Equatable {
    var currentPassword: ValidationError?
    var newPassword: ValidationError?
    var confirmPassword: ValidationError?

    var isValid: Bool { currentPassword == nil && newPassword == nil && confirmPassword == nil }
}

final class ValidateCredentialsUseCase: ValidateCredentialsUseCaseProtocol, Sendable {
    static let passwordMinLength = 8
    static let restaurantNameMinLength = 3
    static let restaurantNameMaxLength = 50
    static let descriptionMinLength = 10
    static let descriptionMaxLength = 500
    static let phoneMinLength = 7
    static let phoneMaxLength = 15
    static let maxImageCount = 5
    static let maxImageSizeBytes = 5 * 1024 * 1024

    func validateLogin(email: String, password: String) -> CredentialsValidation {
        let emailError: ValidationError? = switch validateEmailFormat(email) {
        case .empty:         .custom(messageKey: "Please enter email address")
        case .invalidFormat: .custom(messageKey: "Please enter valid email address")
        case let other:      other
        }

        return CredentialsValidation(
            email: emailError,
            password: validateLoginPassword(password)
        )
    }

    private func validateLoginPassword(_ password: String) -> ValidationError? {
        if password.isEmpty { return .custom(messageKey: "Please enter password") }

        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasSpecialCharacter = password.contains { $0.isSymbol || $0.isPunctuation }
        let hasSpace = password.contains { $0.isWhitespace }

        guard password.count >= Self.passwordMinLength,
              hasUppercase, hasLowercase, hasSpecialCharacter, !hasSpace else {
            return .custom(messageKey:
                "Password must be at least 8 characters long with uppercase, lowercase, special character, and no spaces"
            )
        }
        return nil
    }

    func validateRegistration(_ input: RegistrationValidationInput) -> RegistrationValidation {
        let imagesError: ValidationError? = {
            if input.imageCount == 0 { return .custom(messageKey: "Please add at least one image.") }
            if input.imageCount > Self.maxImageCount {
                return .custom(messageKey: "You can upload up to \(Self.maxImageCount) images.")
            }
            return nil
        }()

        return RegistrationValidation(
            restaurantName: validateRestaurantName(input.restaurantName),
            restaurantNameIcelandic: validateRestaurantName(input.restaurantNameIcelandic),
            email: validateEmailFormat(input.email),
            password: validatePasswordStrength(input.password),
            confirmPassword: validateConfirmPassword(input.confirmPassword, matches: input.password),
            phoneNumber: validatePhoneNumber(input.phoneNumber),
            description: validateDescription(input.description),
            descriptionIcelandic: validateDescription(input.descriptionIcelandic),
            address: input.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : nil,
            city: input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : nil,
            images: imagesError,
            document: input.hasDocument ? nil : .custom(messageKey: "Please upload a document.")
        )
    }

    func validateNewPassword(_ password: String, confirm: String) -> NewPasswordValidation {
        NewPasswordValidation(
            password: validatePasswordStrength(password),
            confirm: validateConfirmPassword(confirm, matches: password)
        )
    }

    func validateChangePassword(current: String, new: String, confirm: String) -> ChangePasswordValidation {
        ChangePasswordValidation(
            currentPassword: current.isEmpty ? .empty : nil,
            newPassword: validateNewPasswordForChange(new, current: current),
            confirmPassword: validateConfirmPassword(confirm, matches: new)
        )
    }

    /// The new password must meet the same strength policy as any other new password, and must
    /// differ from the current one — checked only once both are non-empty, so it never masks
    /// the plain "empty"/strength errors.
    private func validateNewPasswordForChange(_ new: String, current: String) -> ValidationError? {
        if let strengthError = validatePasswordStrength(new) { return strengthError }
        if !current.isEmpty, new == current {
            return .custom(messageKey:
                "New password cannot be the same as your current password. Please choose a different one."
            )
        }
        return nil
    }

    private func validateConfirmPassword(_ confirm: String, matches password: String) -> ValidationError? {
        if confirm.isEmpty { return .empty }
        if confirm != password {
            return .custom(messageKey: "New password and confirm new password do not match")
        }
        return nil
    }

    /// Requires a non-empty local part, and a domain made of one or more non-empty
    /// `label.` segments followed by a letters-only TLD (2+ chars) — rejects things the old
    /// "just contains a dot somewhere" check let through, like `user@.com` or `user@com.`.
    private static let emailPattern = /^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$/

    func validateEmailFormat(_ email: String) -> ValidationError? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }
        guard trimmed.wholeMatch(of: Self.emailPattern) != nil else { return .invalidFormat }
        // `emailPattern`'s local-part character class allows repeated `.`s (e.g.
        // `name...last@gmail.com`, `john..doe@example.com`), which isn't a valid local part per
        // RFC 5321/5322 — reject those explicitly rather than loosening the regex itself.
        let localPart = trimmed.split(separator: "@", maxSplits: 1).first ?? Substring(trimmed)
        guard !localPart.contains("..") else { return .invalidFormat }
        return nil
    }

    private func validatePasswordStrength(_ password: String) -> ValidationError? {
        if password.isEmpty { return .empty }

        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasSpecialCharacter = password.contains { $0.isSymbol || $0.isPunctuation }
        let hasSpace = password.contains { $0.isWhitespace }

        guard password.count >= Self.passwordMinLength,
              hasUppercase, hasLowercase, hasSpecialCharacter, !hasSpace else {
            return .custom(messageKey:
                "Password must be at least 8 characters long with uppercase, lowercase, special character, and no spaces"
            )
        }
        return nil
    }

    private func validateRestaurantName(_ name: String) -> ValidationError? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count < Self.restaurantNameMinLength {
            return .tooShort(min: Self.restaurantNameMinLength)
        }
        return nil
    }

    private func validateDescription(_ description: String) -> ValidationError? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count < Self.descriptionMinLength {
            return .tooShort(min: Self.descriptionMinLength)
        }
        if trimmed.count > Self.descriptionMaxLength {
            return .tooLong(max: Self.descriptionMaxLength)
        }
        return nil
    }

    func validatePhoneNumber(_ phone: String) -> ValidationError? {
        let digits = phone.filter(\.isNumber)
        if digits.isEmpty { return .empty }
        if digits.count < Self.phoneMinLength || digits.count > Self.phoneMaxLength {
            return .custom(messageKey: "Phone number should be between 7 to 15 digits")
        }
        return nil
    }
}
