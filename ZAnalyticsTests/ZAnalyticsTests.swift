import XCTest
@testable import ZAnalytics

final class ZAnalyticsTests: XCTestCase {
    func testCSVTokenParsingTrimsAndDropsEmptyItems() {
        XCTAssertEqual(" requests, blocked, , users ".csvTokens, ["requests", "blocked", "users"])
    }

    func testReportRequestUsesDefinitionDefaults() {
        let definition = ReportCatalog.defaults.first { $0.id == "web-usage" }!
        let request = ReportRequest(definition: definition)

        XCTAssertEqual(request.endpointKey, "web")
        XCTAssertEqual(request.fields, ["requests", "bandwidth_mb", "blocked", "allowed", "category"])
        XCTAssertEqual(request.dimensions, ["category", "location"])
        XCTAssertEqual(request.limit, 250)
    }

    func testCSVWriterEscapesCommasAndQuotes() {
        let result = ReportResult(
            reportName: "Test",
            endpointPath: "/mock",
            requestID: "test",
            dateRangeDescription: "Today",
            summaryCards: [],
            rows: [["name": .string("A, \"quoted\" value"), "count": .int(2)]],
            rawJSON: "{}"
        )

        let csv = CSVReportWriter.csv(for: result)
        XCTAssertTrue(csv.contains("\"A, \"\"quoted\"\" value\""))
    }

    func testMockDataProducesRowsAndSummaryCards() {
        let definition = ReportCatalog.defaults.first { $0.id == "threat-overview" }!
        let result = MockDataProvider.result(for: ReportRequest(definition: definition), definition: definition)

        XCTAssertFalse(result.rows.isEmpty)
        XCTAssertFalse(result.summaryCards.isEmpty)
        XCTAssertTrue(result.requestID.hasPrefix("mock-"))
    }

    func testTokenInspectorExtractsExpiryAndScopesFromJWT() throws {
        let payload = #"{"exp":1893456000,"scope":"read:analytics write:reports","sub":"client-1","aud":"https://api.zscaler.com"}"#
        let token = "header.\(Self.base64URL(payload)).signature"

        let metadata = TokenInspector.inspect(token, fallbackExpiry: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(metadata.scopes, ["read:analytics", "write:reports"])
        XCTAssertEqual(metadata.subject, "client-1")
        XCTAssertEqual(metadata.audience, "https://api.zscaler.com")
        XCTAssertEqual(metadata.expiresAt, Date(timeIntervalSince1970: 1_893_456_000))
    }

    func testOneAPISettingsNormalizesLegacyAudienceDefault() {
        var settings = OneAPISettings.empty
        XCTAssertEqual(settings.normalizedAudience, "https://api.zscaler.com")

        settings.audience = "zscaler-oneapi"
        XCTAssertEqual(settings.normalizedAudience, "https://api.zscaler.com")

        settings.audience = "custom-audience"
        XCTAssertEqual(settings.normalizedAudience, "custom-audience")
    }

    func testGraphQLRequestBodyIncludesQueryAndMergedVariables() throws {
        let definition = ReportCatalog.defaults.first { $0.id == "web-usage" }!
        let request = ReportRequest(definition: definition)
        let template = EndpointTemplate(
            key: "web",
            displayName: "Web GraphQL",
            category: "Web",
            transport: .graphql,
            pathTemplate: "/unused",
            graphqlQuery: "query Test($limit: Int) { webAnalytics(limit: $limit) { rows } }",
            graphqlVariablesJSON: #"{"tenantHint":"demo"}"#,
            notes: "test"
        )

        let data = try GraphQLRequestBuilder.body(for: request, template: template)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let variables = object?["variables"] as? [String: Any]

        XCTAssertEqual(object?["query"] as? String, template.graphqlQuery)
        XCTAssertEqual(variables?["tenantHint"] as? String, "demo")
        XCTAssertEqual(variables?["limit"] as? Int, request.limit)
        XCTAssertEqual(variables?["report"] as? String, "web-usage")
        XCTAssertNotNil(variables?["dateRange"] as? [String: Any])
    }

    func testGraphQLVariablesOverrideDefaultReportVariables() throws {
        let definition = ReportCatalog.defaults.first { $0.id == "web-usage" }!
        let request = ReportRequest(definition: definition)
        let template = EndpointTemplate(
            key: "web",
            displayName: "Web GraphQL",
            category: "Web",
            transport: .graphql,
            pathTemplate: "/unused",
            graphqlQuery: "query Test($limit: Int) { webAnalytics(limit: $limit) { rows } }",
            graphqlVariablesJSON: #"{"limit":12,"customFlag":true}"#,
            notes: "test"
        )

        let data = try GraphQLRequestBuilder.body(for: request, template: template)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let variables = try XCTUnwrap(object["variables"] as? [String: Any])

        XCTAssertEqual(variables["limit"] as? Int, 12)
        XCTAssertEqual(variables["customFlag"] as? Bool, true)
    }

    func testGraphQLResponseParserFindsNestedDataRows() {
        let json = """
        {
          "data": {
            "webAnalytics": {
              "rows": [
                { "category": "Business", "requests": 25 },
                { "category": "Unknown", "requests": 8 }
              ]
            }
          }
        }
        """
        let rows = OneAPIResponseParser.rows(from: Data(json.utf8))

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first?["category"], .string("Business"))
        XCTAssertEqual(rows.first?["requests"], .int(25))
    }

    func testGraphQLResponseParserKeepsEmptyNestedRowsEmpty() {
        let json = #"{"data":{"webAnalytics":{"rows":[]}}}"#
        let rows = OneAPIResponseParser.rows(from: Data(json.utf8))

        XCTAssertTrue(rows.isEmpty)
    }

    func testHTMLRendererIncludesTemplateChartsSectionsAndDisclaimer() {
        let result = ReportResult(
            reportName: "Threat Overview",
            endpointPath: "/mock",
            requestID: "test",
            dateRangeDescription: "Today",
            summaryCards: [SummaryCard(title: "Rows", value: "2", detail: "Returned records")],
            rows: [
                ["severity": .string("Critical"), "threat_type": .string("Phishing"), "detections": .int(42)],
                ["severity": .string("High"), "threat_type": .string("Malware"), "detections": .int(18)]
            ],
            rawJSON: "{}",
            presentationTemplate: .executiveSummary
        )

        let html = HTMLReportRenderer.html(for: result, template: .customerSuccessReview)

        XCTAssertTrue(html.contains("Customer Success Review"))
        XCTAssertTrue(html.contains("Top Values"))
        XCTAssertTrue(html.contains("Trend View"))
        XCTAssertTrue(html.contains("<svg role=\"img\" aria-label=\"Trend line chart\""))
        XCTAssertTrue(html.contains("Severity and Category Sections"))
        XCTAssertTrue(html.contains("Methodology"))
        XCTAssertTrue(html.contains("unofficial helper"))
        XCTAssertFalse(html.contains("https://cdn"))
    }

    func testPDFRendererWritesPDFFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zanalytics-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        try PDFReportRenderer.write(Self.sampleResult(), template: .executiveSummary, to: url)
        let data = try Data(contentsOf: url)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1_000)
    }

    func testPowerPointRendererWritesPPTXPackage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zanalytics-test-\(UUID().uuidString).pptx")
        defer { try? FileManager.default.removeItem(at: url) }

        try PowerPointReportRenderer.write(Self.sampleResult(), template: .technicalDetail, to: url)
        let data = try Data(contentsOf: url)

        XCTAssertTrue(data.starts(with: Data([0x50, 0x4B])))
        XCTAssertGreaterThan(data.count, 1_000)
    }

    private static func sampleResult() -> ReportResult {
        ReportResult(
            reportName: "Threat Overview",
            endpointPath: "/mock",
            requestID: "test",
            dateRangeDescription: "Today",
            summaryCards: [
                SummaryCard(title: "Rows", value: "2", detail: "Returned records"),
                SummaryCard(title: "Blocked", value: "42", detail: "Blocked requests")
            ],
            rows: [
                ["severity": .string("Critical"), "threat_type": .string("Phishing"), "detections": .int(42)],
                ["severity": .string("High"), "threat_type": .string("Malware"), "detections": .int(18)]
            ],
            rawJSON: "{}",
            presentationTemplate: .executiveSummary
        )
    }

    private static func base64URL(_ string: String) -> String {
        string.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
