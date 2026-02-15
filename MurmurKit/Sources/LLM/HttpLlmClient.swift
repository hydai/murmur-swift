import Foundation

/// Authentication strategy for HTTP LLM APIs.
public enum HttpLlmAuth: Sendable {
    /// Bearer token in Authorization header.
    case bearer(String)
    /// Anthropic-style API key header.
    case anthropicHeader(String)
    /// API key as a URL query parameter.
    case queryParam(key: String, value: String)
    /// No authentication (e.g., local models).
    case none
}

/// Stateless HTTP client for LLM API requests.
public struct HttpLlmClient: Sendable {
    private let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Send a POST request with JSON body and return the raw response data.
    public func post(url: URL, body: Data, auth: HttpLlmAuth, extraHeaders: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds
        request.httpBody = body

        applyAuth(auth, to: &request)

        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MurmurError.network("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw MurmurError.network("HTTP \(httpResponse.statusCode): \(body)")
        }

        return data
    }

    private func applyAuth(_ auth: HttpLlmAuth, to request: inout URLRequest) {
        switch auth {
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .anthropicHeader(let key):
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        case .queryParam, .none:
            break
        }
    }

    /// Build a URL with optional query parameter authentication.
    public static func buildURL(base: String, auth: HttpLlmAuth) throws -> URL {
        switch auth {
        case .queryParam(let key, let value):
            guard var components = URLComponents(string: base) else {
                throw MurmurError.network("Invalid URL: \(base)")
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: key, value: value))
            components.queryItems = items
            guard let url = components.url else {
                throw MurmurError.network("Failed to construct URL from: \(base)")
            }
            return url
        default:
            guard let url = URL(string: base) else {
                throw MurmurError.network("Invalid URL: \(base)")
            }
            return url
        }
    }
}
