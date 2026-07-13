import Foundation

/// Mirrors Android's `OfferApi`. Unlike Restaurant/Images, these paths are clean — no doubled
/// `/api/api` segment (the base URL already ends in `/api`, and Android's Retrofit paths here
/// have no extra leading `api/`).
enum OfferEndpoint: Endpoint {
    case listOffers(page: Int, limit: Int)
    case getOffer(id: Int64)
    /// `body`/`boundary` are precomputed by the repository (which owns the
    /// `MultipartFormData` build), same pattern as `EditRestaurantEndpoint`/`ImageEndpoint`.
    case createOffer(body: Data, boundary: String)
    case updateOffer(id: Int64, body: Data, boundary: String)
    case deleteOffer(id: Int64)
    case getAnalytics(id: Int64)

    var baseURL: URL { URL(string: "http://161.97.132.85:3688/api")! }

    var path: String {
        switch self {
        case .listOffers, .createOffer:
            return "/owner/offers"
        case .getOffer(let id):
            return "/owner/offers/\(id)"
        case .updateOffer(let id, _, _):
            return "/owner/offers/\(id)"
        case .deleteOffer(let id):
            return "/owner/offers/\(id)"
        case .getAnalytics(let id):
            return "/owner/offers/\(id)/analytics"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listOffers, .getOffer, .getAnalytics:
            return .get
        case .createOffer:
            // Android's `createOffer` has no Idempotency-Key header either.
            return .post(idempotencyKey: nil)
        case .updateOffer:
            return .put()
        case .deleteOffer:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listOffers(let page, let limit):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        default:
            return nil
        }
    }

    var headers: [String: String] {
        switch self {
        case .createOffer(_, let boundary), .updateOffer(_, _, let boundary):
            return ["Content-Type": "multipart/form-data; boundary=\(boundary)", "Accept": "application/json"]
        default:
            return ["Content-Type": "application/json", "Accept": "application/json"]
        }
    }

    var body: Data? {
        switch self {
        case .createOffer(let body, _):
            return body
        case .updateOffer(_, let body, _):
            return body
        default:
            return nil
        }
    }
}
