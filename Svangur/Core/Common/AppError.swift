import SwiftUI

// MARK: - App-Wide Typed Error

enum AppError: Error, Equatable, Sendable {
    case network(message: String = "Network error")
    case server(code: Int, message: String)
    case unauthorized(message: String = "Session expired")
    case notFound(message: String = "Not found")
    case validation(message: String)
    case biometricUnavailable
    case biometricFailed(reason: String)
    case unknown(message: String = "Something went wrong")
}

// MARK: - User-Facing Message (Localized)

extension AppError {
    var userMessage: LocalizedStringKey {
        switch self {
        case .network:
            return "error_network"
        case .server(let code, _):
            return "Server error: \(code)"
        case .unauthorized:
            return "error_session_expired"
        case .notFound:
            return "error_not_found"
        case .validation(let message):
            return LocalizedStringKey(message)
        case .biometricUnavailable:
            return "error_biometric_unavailable"
        case .biometricFailed:
            return "error_biometric_failed"
        case .unknown:
            return "error_generic"
        }
    }
}

// MARK: - Plain String for ViewModel State

extension AppError {
    var displayMessage: String {
        switch self {
        case .network(let message): return message
        case .server(let code, let message): return "Server error \(code): \(message)"
        case .unauthorized(let message): return message
        case .notFound(let message): return message
        case .validation(let message): return message
        case .biometricUnavailable: return "Biometric authentication unavailable"
        case .biometricFailed(let reason): return reason
        case .unknown(let message): return message
        }
    }
}

// MARK: - Mapping from Untyped Errors

extension Error {
    func toAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        }
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost:
                return .network()
            default:
                return .network(message: urlError.localizedDescription)
            }
        }
        return .unknown(message: localizedDescription)
    }
}

// MARK: - Typed-Throws API Call Wrapper

func apiCall<T>(_ operation: () async throws -> T) async throws(AppError) -> T {
    do {
        return try await operation()
    } catch let error as AppError {
        throw error
    } catch {
        throw error.toAppError()
    }
}
