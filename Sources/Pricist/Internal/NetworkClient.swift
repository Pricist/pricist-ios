import Foundation

let pricistDefaultBaseURL = "https://api.pricist.com"

/// Resolve the SDK base host (no trailing slash, no path). `host` is also
/// trimmed at construction time, but we re-trim here so a hand-set override
/// stays sane.
func pricistResolveBaseURL(_ configuration: PricistConfiguration) -> String {
    let trimmed = (configuration.host ?? pricistDefaultBaseURL)
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return trimmed.isEmpty ? pricistDefaultBaseURL : trimmed
}

/// HTTP client for the Pricist ingest + config endpoints.
final class NetworkClient {

    private let session: URLSession
    private let encoder: JSONEncoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // Keys are already camelCase to match the backend contract — do NOT
        // apply a key-encoding strategy.
        self.encoder = JSONEncoder()
    }

    /// Send a single event to `POST /api/track`. The backend ingests one
    /// event per request and dedups on (eventId, timestamp), so retrying a
    /// failed send with the same event is safe.
    func sendEvent(
        _ event: PricistEvent,
        configuration: PricistConfiguration,
        completion: @escaping (Result<Void, NetworkError>) -> Void
    ) {
        guard let url = URL(string: "\(pricistResolveBaseURL(configuration))/api/track") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.sdkKey, forHTTPHeaderField: "x-pricist-sdk-key")

        do {
            request.httpBody = try encoder.encode(event)
        } catch {
            completion(.failure(.encodingError(error)))
            return
        }

        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            completion(Self.mapStatus(httpResponse.statusCode) ?? .success(()))
        }

        task.resume()
    }

    /// Send a session to `POST /api/session` and decode the sanitized
    /// attribution result. Carries the `x-pricist-sdk-key` header and mirrors
    /// `sendEvent`'s status mapping (401 → `.unauthorized`, etc.).
    func sendSession(
        _ request: SessionRequest,
        configuration: PricistConfiguration,
        completion: @escaping (Result<AttributionResult, NetworkError>) -> Void
    ) {
        guard let url = URL(string: "\(pricistResolveBaseURL(configuration))/api/session") else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(configuration.sdkKey, forHTTPHeaderField: "x-pricist-sdk-key")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            completion(.failure(.encodingError(error)))
            return
        }

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            if let mapped = Self.mapStatus(httpResponse.statusCode) {
                // Non-2xx — surface the failure.
                if case .failure(let err) = mapped { completion(.failure(err)) }
                return
            }
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            do {
                // Keys are already camelCase on the wire — no decoding strategy.
                let result = try JSONDecoder().decode(AttributionResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(.encodingError(error)))
            }
        }

        task.resume()
    }

    /// Fetch remote config (feature flags) from `GET /api/sdk/config`.
    /// Returns the project's flags as a typed key/value map.
    func fetchConfig(
        configuration: PricistConfiguration,
        completion: @escaping (Result<[String: Any], NetworkError>) -> Void
    ) {
        guard let url = URL(string: "\(pricistResolveBaseURL(configuration))/api/sdk/config") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.sdkKey, forHTTPHeaderField: "x-pricist-sdk-key")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            if let mapped = Self.mapStatus(httpResponse.statusCode) {
                // Non-2xx — surface the failure.
                if case .failure(let err) = mapped { completion(.failure(err)) }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(.invalidResponse))
                return
            }
            // The endpoint returns `{ "config": { key: value, ... } }`.
            let config = (json["config"] as? [String: Any]) ?? json
            completion(.success(config))
        }

        task.resume()
    }

    /// Map an HTTP status to a `NetworkError` result. Returns `nil` for 2xx
    /// (let the caller decide the success payload).
    private static func mapStatus(_ code: Int) -> Result<Void, NetworkError>? {
        switch code {
        case 200...299: return nil
        case 401: return .failure(.unauthorized)
        case 429: return .failure(.rateLimited)
        case 400...499: return .failure(.clientError(code))
        case 500...599: return .failure(.serverError(code))
        default: return .failure(.unknownError(code))
        }
    }
}

// MARK: - Errors

enum NetworkError: Error {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case rateLimited
    case clientError(Int)
    case serverError(Int)
    case unknownError(Int)

    /// Whether retrying the same request later could succeed. 4xx (except
    /// 429) are permanent — dropping the event avoids a poison-pill queue.
    var isRetryable: Bool {
        switch self {
        case .unauthorized, .clientError:
            return false
        case .invalidURL, .encodingError:
            return false
        default:
            return true
        }
    }
}
