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
        let pathTemplate = template.transport == .graphql ? template.graphqlEndpointPath : template.pathTemplate
        let path = pathTemplate.replacingOccurrences(of: "{tenantId}", with: settings.tenantID)
        let url = try makeURL(path: path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = template.transport == .graphql ? HTTPMethod.post.rawValue : template.method.rawValue
        urlRequest.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(requestID, forHTTPHeaderField: "X-Request-ID")

        if template.transport == .graphql {
            urlRequest.httpBody = try GraphQLRequestBuilder.body(for: request, template: template)
        } else if template.method == .post {
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
            rawJSON: rawJSON,
            presentationTemplate: request.presentationTemplate
        )
    }

    func authenticate() async throws -> AuthResult {
        let token = try await accessToken()
        return AuthResult(token: token, metadata: TokenInspector.inspect(token.value, fallbackExpiry: token.expiresAt))
    }

    func testConnection(_ request: ReportRequest, using templates: [EndpointTemplate]) async throws -> ConnectionTestResult {
        let result = try await runReport(request, using: templates)
        return ConnectionTestResult(
            requestID: result.requestID,
            endpointPath: result.endpointPath,
            rowCount: result.rows.count,
            generatedAt: result.generatedAt
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
        let tokenURL = try makeTokenURL()
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")

        var components = URLComponents()
        var queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: settings.clientID),
            URLQueryItem(name: "client_secret", value: settings.clientSecret)
        ]
        let audience = settings.normalizedAudience
        if !audience.isEmpty {
            queryItems.append(URLQueryItem(name: "audience", value: audience))
        }
        components.queryItems = queryItems
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

    private func makeTokenURL() throws -> URL {
        if settings.tokenPath.hasPrefix("http"), let url = URL(string: settings.tokenPath) {
            return url
        }

        let vanityDomain = settings.vanityDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vanityDomain.isEmpty {
            let host = vanityDomain.contains(".") ? vanityDomain : "\(vanityDomain).zslogin.net"
            guard let base = URL(string: "https://\(host)") else {
                throw OneAPIError.invalidBaseURL
            }
            return base.appendingPathComponent(settings.tokenPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        return try makeURL(path: settings.tokenPath)
    }
}

struct AccessToken {
    let value: String
    let expiresAt: Date
}

struct AuthResult {
    let token: AccessToken
    let metadata: TokenMetadata

    var statusText: String {
        var parts = ["Token OK"]
        parts.append("expires: \(metadata.expiryDescription)")
        if !metadata.scopes.isEmpty {
            parts.append("scopes: \(metadata.scopes.joined(separator: ", "))")
        } else {
            parts.append("scopes: not present in token")
        }
        if let subject = metadata.subject, !subject.isEmpty {
            parts.append("subject: \(subject)")
        }
        return parts.joined(separator: " | ")
    }
}

struct ConnectionTestResult {
    let requestID: String
    let endpointPath: String
    let rowCount: Int
    let generatedAt: Date
}

struct TokenMetadata {
    let expiresAt: Date?
    let scopes: [String]
    let subject: String?
    let issuer: String?
    let audience: String?

    var expiryDescription: String {
        guard let expiresAt else { return "unknown" }
        return expiresAt.formatted(date: .abbreviated, time: .shortened)
    }
}

enum TokenInspector {
    static func inspect(_ token: String, fallbackExpiry: Date) -> TokenMetadata {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = decodeBase64URL(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return TokenMetadata(expiresAt: fallbackExpiry, scopes: [], subject: nil, issuer: nil, audience: nil)
        }

        let expiry = (json["exp"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? fallbackExpiry
        let scopes = extractScopes(from: json)
        let audience: String?
        if let aud = json["aud"] as? String {
            audience = aud
        } else if let aud = json["aud"] as? [String] {
            audience = aud.joined(separator: ", ")
        } else {
            audience = nil
        }

        return TokenMetadata(
            expiresAt: expiry,
            scopes: scopes,
            subject: json["sub"] as? String,
            issuer: json["iss"] as? String,
            audience: audience
        )
    }

    private static func extractScopes(from json: [String: Any]) -> [String] {
        if let scope = json["scope"] as? String {
            return scope.split(separator: " ").map(String.init).sorted()
        }
        if let scopes = json["scp"] as? [String] {
            return scopes.sorted()
        }
        if let scopes = json["scopes"] as? [String] {
            return scopes.sorted()
        }
        return []
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
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
    case invalidGraphQLQuery
    case invalidGraphQLVariables(String)
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
        case .invalidGraphQLQuery:
            return "GraphQL transport is selected, but the endpoint template has no query text."
        case .invalidGraphQLVariables(let message):
            return "GraphQL variables JSON is invalid: \(message)"
        case .missingEndpointTemplate(let key):
            return "No endpoint template is configured for '\(key)'. Open Settings and add or reset endpoint templates."
        case .signedJWTNotConfigured:
            return "Signed JWT authentication is reserved for a future local signing configuration. Use client secret auth for now, or keep mock mode enabled."
        }
    }
}

enum GraphQLRequestBuilder {
    static func body(for request: ReportRequest, template: EndpointTemplate) throws -> Data {
        let query = template.graphqlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw OneAPIError.invalidGraphQLQuery
        }

        let variables = try mergedVariables(for: request, variablesJSON: template.graphqlVariablesJSON)
        let payload: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    private static func mergedVariables(for request: ReportRequest, variablesJSON: String) throws -> [String: Any] {
        var variables = request.payload()
        variables["startTime"] = Int(request.startDate.timeIntervalSince1970 * 1000)
        variables["endTime"] = Int(request.endDate.timeIntervalSince1970 * 1000)
        variables["limit"] = request.limit
        let trimmed = variablesJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return variables
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw OneAPIError.invalidGraphQLVariables("Unable to encode variables as UTF-8.")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw OneAPIError.invalidGraphQLVariables("Variables must be a JSON object.")
            }
            dictionary.forEach { variables[$0.key] = $0.value }
            return variables
        } catch let error as OneAPIError {
            throw error
        } catch {
            throw OneAPIError.invalidGraphQLVariables(error.localizedDescription)
        }
    }
}

enum OneAPIResponseParser {
    static func rows(from data: Data) -> [[String: ReportValue]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        return rows(fromJSONObject: object)
    }

    static func rows(fromJSONObject object: Any) -> [[String: ReportValue]] {
        rowsResult(fromJSONObject: object) ?? []
    }

    private static func rowsResult(fromJSONObject object: Any) -> [[String: ReportValue]]? {
        if let rows = object as? [[String: Any]] {
            return rows.map(normalizeGraphQLRow).map(convertRow)
        }

        if object is [Any] {
            return []
        }

        if let dictionary = object as? [String: Any] {
            for key in ["rows", "results", "items", "records", "nodes"] {
                if let value = dictionary[key] {
                    if let rows = value as? [[String: Any]] {
                        return rows.map(normalizeGraphQLRow).map(convertRow)
                    }
                    if value is [Any] {
                        return []
                    }
                }
            }

            if let value = dictionary["edges"] {
                if let edges = value as? [[String: Any]] {
                    return edges.compactMap { $0["node"] as? [String: Any] }.map(convertRow)
                }
                if value is [Any] {
                    return []
                }
            }

            if let data = dictionary["data"] {
                return rowsResult(fromJSONObject: data) ?? []
            }

            let nestedKeys = dictionary.keys.sorted()
            for key in nestedKeys {
                if let nested = dictionary[key],
                   nested is [[String: Any]] || nested is [String: Any] || nested is [Any] {
                    return rowsResult(fromJSONObject: nested)
                }
            }

            return [convertRow(dictionary)]
        }

        return nil
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

    private static func normalizeGraphQLRow(_ row: [String: Any]) -> [String: Any] {
        if let node = row["node"] as? [String: Any] {
            return node
        }
        return row
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
