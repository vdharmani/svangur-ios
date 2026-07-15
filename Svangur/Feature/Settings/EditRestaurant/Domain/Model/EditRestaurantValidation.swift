import Foundation

/// Only covers the fields this screen actually lets the user edit (`address`/`city` are
/// display-only here, loaded from the profile with no field to fix them from — mirroring
/// `RegistrationValidation`'s documented judgment call for the same reason).
struct EditRestaurantValidation: Sendable, Equatable {
    var nameEn: ValidationError?
    var nameIs: ValidationError?
    var descriptionEn: ValidationError?
    var descriptionIs: ValidationError?
    var images: ValidationError?

    var isValid: Bool {
        nameEn == nil && nameIs == nil && descriptionEn == nil && descriptionIs == nil && images == nil
    }
}
