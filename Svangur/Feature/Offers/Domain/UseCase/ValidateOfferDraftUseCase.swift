import Foundation

struct OfferDraftValidationErrors: Sendable, Equatable {
    var title: ValidationError?
    var description: ValidationError?
    var category: ValidationError?
    var discount: ValidationError?
    var validDays: ValidationError?
    var validTime: ValidationError?

    var isValid: Bool {
        title == nil && description == nil && category == nil &&
        discount == nil && validDays == nil && validTime == nil
    }
}

enum ValidationError: Error, Equatable, Sendable {
    case empty
    case tooShort(min: Int)
    case tooLong(max: Int)
    case invalidFormat
    case custom(messageKey: String)
}

protocol ValidateOfferDraftUseCaseProtocol: Sendable {
    func execute(_ draft: OfferDraft) -> OfferDraftValidationErrors
}

final class ValidateOfferDraftUseCase: ValidateOfferDraftUseCaseProtocol, Sendable {
    static let titleMaxLength = 60
    static let descriptionMaxLength = 150
    static let titleMinLength = 3
    static let maxImageCount = 5

    func execute(_ draft: OfferDraft) -> OfferDraftValidationErrors {
        var errors = OfferDraftValidationErrors()

        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errors.title = .empty
        } else if trimmedTitle.count < Self.titleMinLength {
            errors.title = .tooShort(min: Self.titleMinLength)
        } else if trimmedTitle.count > Self.titleMaxLength {
            errors.title = .tooLong(max: Self.titleMaxLength)
        }

        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            errors.description = .empty
        } else if trimmedDescription.count > Self.descriptionMaxLength {
            errors.description = .tooLong(max: Self.descriptionMaxLength)
        }

        if draft.categoryId == nil {
            errors.category = .empty
        }

        if draft.discountId == nil {
            errors.discount = .empty
        }

        if draft.validDays.isEmpty {
            errors.validDays = .empty
        }

        if draft.validTimeEnd <= draft.validTimeStart {
            errors.validTime = .custom(messageKey: "form.error.end_before_start")
        }

        return errors
    }
}
