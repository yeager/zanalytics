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
}
