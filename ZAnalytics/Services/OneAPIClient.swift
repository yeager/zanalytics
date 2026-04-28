import Foundation

final class OneAPIClient {
    private let settings: OneAPISettings
    private let session: URLSession
    private var cachedToken: AccessToken?

    init(settings: OneAPISettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func runReport(_ request: ReportRequest, using templates: [EndpointTemplate]) async throws -> ReportResult {
        guard let template = templates.first(where: { $0.key == request.endpointKey }) else {
            throw OneAPIError.missingEndpointTemplate(request.endpointKey)
        }

        let requestID = UUID().uuidString
        let token = try await accessToken()
        let path = template.pathTemplate.replacingOccurrences(of: "{tenantId}", with: settings.tenantID)
        let url = try makeURL(path: path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = template.method.rawValue
        urlRequest.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(requestID, forHTTPHeaderField: "X-Request-ID")

        if template.method == .post {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request.payload(), options: [.sortedKeys])
        }

        let data = try await sendWithRetry(urlRequest)
        let rows = OneAPIResponseParser.rows(from: data)
        let rawJSON = String(data: data, encoding: .utf8) ?? "{}"
        return ReportResult(
            reportName: request.reportName,
            endpointPath: path,
            requestID: requestID,
            dateRangeDescription: "\(request.startDate.formatted(date: .abbreviated, time: .omitted)) - \(request.endDate.formatted(date: .abbreviated, time: .omitted))",
            summaryCards: OneAPIResponseParser.summaryCards(from: rows),
            rows: rows,
            rawJSON: rawJSON
        )
    }

    private func accessToken() async throws -> AccessToken {
        if let cachedToken, cachedToken.expiresAt.timeIntervalSinceNow > 60 {
            return cachedToken
        }

        switch settings.authMethod {
        case .clientSecret:
            let token = try await requestClientSecretToken()
            cachedToken = token
            return token
        case .signedJWT:
            throw OneAPIError.signedJWTNotConfigured
        }
    }

    private func requestClientSecretToken() async throws -> AccessToken {
        let tokenURL = try makeURL(path: settings.tokenPath)
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: settings.clientID),
            URLQueryItem(name: "client_secret", value: settings.clientSecret),
            URLQueryItem(name: "audience", value: settings.audience)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data = try await sendWithRetry(request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return AccessToken(
            value: response.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(response.expiresIn - 30, 60)))
        )
    }

    private func sendWithRetry(_ request: URLRequest) async throws -> Data {
        var attempt = 0
        var lastError: Error?

        while attempt < 3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw OneAPIError.invalidResponse
                }

                if (200..<300).contains(http.statusCode) {
                    return data
                }

                if http.statusCode == 429 || (500..<600).contains(http.statusCode) {
                    let delay = retryDelay(from: http, attempt: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }

                let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                throw OneAPIError.httpStatus(http.statusCode, message)
            } catch {
                lastError = error
                if attempt >= 2 {
                    break
                }
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 500_000_000))
                attempt += 1
            }
        }

        throw lastError ?? OneAPIError.invalidResponse
    }

    private func retryDelay(from response: HTTPURLResponse, attempt: Int) -> TimeInterval {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter) {
            return min(seconds, 30)
        }
        return min(pow(2.0, Double(attempt)), 8)
    }

    private func makeURL(path: String) throws -> URL {
        guard let base = URL(string: settings.normalizedBaseURL) else {
            throw OneAPIError.invalidBaseURL
        }
        if path.hasPrefix("http"), let url = URL(string: path) {
            return url
        }
        return base.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

struct AccessToken {
    let value: String
    let expiresAt: Date
}

struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

enum OneAPIError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case missingEndpointTemplate(String)
    case signedJWTNotConfigured

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The OneAPI base URL is not a valid URL."
        case .invalidResponse:
            return "OneAPI returned an invalid response."
        case .httpStatus(let code, let message):
            return "OneAPI request failed with HTTP \(code): \(message)"
        case .missingEndpointTemplate(let key):
            return "No endpoint template is configured for '\(key)'. Open Settings and add or reset endpoint templates."
        case .signedJWTNotConfigured:
            return "Signed JWT authentication is reserved for a future local signing configuration. Use client secret auth for now, or keep mock mode enabled."
        }
    }
}

enum OneAPIResponseParser {
    static func rows(from data: Data) -> [[String: ReportValue]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        if let dictionary = object as? [String: Any] {
            for key in ["rows", "data", "results", "items"] {
                if let rows = dictionary[key] as? [[String: Any]] {
                    return rows.map(convertRow)
                }
            }
            return [convertRow(dictionary)]
        }

        if let rows = object as? [[String: Any]] {
            return rows.map(convertRow)
        }

        return []
    }

    static func summaryCards(from rows: [[String: ReportValue]]) -> [SummaryCard] {
        let rowCount = rows.count
        let numericValues = rows.flatMap { row in
            row.values.compactMap { value -> Double? in
                switch value {
                case .int(let int): return Double(int)
                case .double(let double): return double
                default: return nil
                }
            }
        }
        let total = numericValues.reduce(0, +)
        return [
            SummaryCard(title: "Rows", value: "\(rowCount)", detail: "Returned records"),
            SummaryCard(title: "Numeric Total", value: total.formatted(.number.precision(.fractionLength(0...0))), detail: "Sum across numeric cells"),
            SummaryCard(title: "Columns", value: "\(rows.first?.keys.count ?? 0)", detail: "Detected fields")
        ]
    }

    private static func convertRow(_ row: [String: Any]) -> [String: ReportValue] {
        row.reduce(into: [:]) { partial, item in
            partial[item.key] = convert(item.value)
        }
    }

    private static func convert(_ value: Any) -> ReportValue {
        switch value {
        case let value as String: return .string(value)
        case let value as Int: return .int(value)
        case let value as Double: return .double(value)
        case let value as Bool: return .bool(value)
        case _ as NSNull: return .null
        default:
            return .string(String(describing: value))
        }
    }
}
