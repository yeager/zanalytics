import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportFormat: CaseIterable, Identifiable {
    case json
    case csv
    case html

    var id: String { extensionName }

    var label: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .html: return "HTML"
        }
    }

    var extensionName: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .html: return "html"
        }
    }
}

final class ReportExportService {
    func export(_ result: ReportResult, as format: ExportFormat, template: ReportPresentationTemplate? = nil) throws -> URL {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(result.reportName.fileSafe)-\(Date().exportStamp).\(format.extensionName)"
        panel.allowedContentTypes = [.init(filenameExtension: format.extensionName)!]

        guard panel.runModal() == .OK, let url = panel.url else {
            throw ExportError.cancelled
        }

        switch format {
        case .json:
            try result.rawJSON.write(to: url, atomically: true, encoding: .utf8)
        case .csv:
            try CSVReportWriter.csv(for: result).write(to: url, atomically: true, encoding: .utf8)
        case .html:
            try HTMLReportRenderer.html(for: result, template: template ?? result.presentationTemplate).write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }
}

enum ExportError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Export cancelled."
        }
    }
}

enum CSVReportWriter {
    static func csv(for result: ReportResult) -> String {
        let headers = Array(Set(result.rows.flatMap { $0.keys })).sorted()
        var lines = [headers.map(escape).joined(separator: ",")]
        for row in result.rows {
            lines.append(headers.map { escape(row[$0]?.description ?? "") }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

enum HTMLReportRenderer {
    static func html(for result: ReportResult, template: ReportPresentationTemplate? = nil) -> String {
        let template = template ?? result.presentationTemplate
        let headers = Array(Set(result.rows.flatMap { $0.keys })).sorted()
        let maxCardValue = result.summaryCards.compactMap { Double($0.value.replacingOccurrences(of: ",", with: "")) }.max() ?? 1
        let cards = result.summaryCards.map { card in
            let numeric = Double(card.value.replacingOccurrences(of: ",", with: "")) ?? 0
            let width = max(8, min(100, Int((numeric / maxCardValue) * 100)))
            return """
            <section class="kpi-card">
              <h3>\(card.title.htmlEscaped)</h3>
              <strong>\(card.value.htmlEscaped)</strong>
              <p>\(card.detail.htmlEscaped)</p>
              <div class="meter"><span style="width: \(width)%"></span></div>
            </section>
            """
        }.joined(separator: "\n")

        let tableRows = result.rows.map { row in
            let cells = headers.map { "<td>\((row[$0]?.description ?? "").htmlEscaped)</td>" }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        let headerCells = headers.map { "<th>\($0.htmlEscaped)</th>" }.joined()
        let templateIntro = intro(for: template, result: result)
        let barChart = barChartHTML(for: result.rows)
        let trendChart = trendChartSVG(for: result.rows)
        let sections = groupedSectionsHTML(for: result.rows)

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(result.reportName.htmlEscaped)</title>
          <style>
            :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #17202a; background: #f4f6f8; }
            body { margin: 0; background: #f4f6f8; }
            main { max-width: 1180px; margin: 0 auto; padding: 28px 28px 60px; }
            .hero { color: white; background: linear-gradient(135deg, #12324a, #1f6f78); padding: 34px 36px; border-radius: 8px; margin-bottom: 20px; }
            .eyebrow { margin: 0 0 10px; color: #bde7df; font-size: 12px; text-transform: uppercase; letter-spacing: .08em; }
            h1 { margin: 0 0 10px; font-size: 34px; }
            h2 { margin: 0 0 12px; font-size: 20px; }
            h3 { margin: 0; font-size: 13px; color: #5c6675; text-transform: uppercase; letter-spacing: .04em; }
            .hero .meta { color: #d7eef0; margin: 5px 0; }
            .notice { background: #fff7df; border: 1px solid #ead28a; padding: 12px 14px; border-radius: 8px; margin: 18px 0; }
            .panel { background: white; border: 1px solid #dfe4ec; border-radius: 8px; padding: 20px; margin: 18px 0; }
            .panel p { color: #4d5968; line-height: 1.5; }
            .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; margin: 18px 0; }
            .kpi-card { background: white; border: 1px solid #dfe4ec; border-radius: 8px; padding: 16px; }
            .kpi-card strong { display: block; font-size: 30px; margin-top: 8px; }
            .kpi-card p { color: #5c6675; margin: 8px 0 12px; }
            .meter { height: 8px; background: #e9edf4; border-radius: 999px; overflow: hidden; }
            .meter span { display: block; height: 100%; background: #1f8f7a; }
            .charts { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 18px; }
            .bar-row { display: grid; grid-template-columns: 145px 1fr 72px; gap: 10px; align-items: center; margin: 10px 0; font-size: 13px; }
            .bar-track { height: 14px; background: #e8edf3; border-radius: 999px; overflow: hidden; }
            .bar-track span { display: block; height: 100%; background: #2364aa; }
            .section-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
            .section-item { border: 1px solid #e4e8ee; border-radius: 8px; padding: 12px; background: #fbfcfd; }
            .section-item strong { display: block; font-size: 24px; margin: 5px 0; }
            table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #dfe4ec; }
            th, td { padding: 10px 12px; border-bottom: 1px solid #edf0f5; text-align: left; font-size: 13px; vertical-align: top; }
            th { background: #eef2f8; color: #374151; }
            footer { color: #5c6675; font-size: 12px; margin-top: 18px; }
            @media (max-width: 780px) { .cards, .charts { grid-template-columns: 1fr; } .bar-row { grid-template-columns: 1fr; } }
            @media print { body { background: white; } main { padding: 0; } .notice, .panel, .kpi-card { break-inside: avoid; } }
          </style>
        </head>
        <body>
          <main>
            <header class="hero">
              <p class="eyebrow">\(template.label.htmlEscaped)</p>
              <h1>\(result.reportName.htmlEscaped)</h1>
              <p class="meta">Generated \(result.generatedAt.formatted(date: .abbreviated, time: .shortened)) for \(result.dateRangeDescription.htmlEscaped)</p>
              <p class="meta">Endpoint: \(result.endpointPath.htmlEscaped) | Request ID: \(result.requestID.htmlEscaped)</p>
            </header>
            <p class="notice">ZAnalytics is an unofficial helper and is not affiliated with, endorsed by, or sponsored by Zscaler. Validate endpoint paths, RBAC, and report semantics against your tenant before using this output operationally.</p>
            <section class="panel">
              <h2>\(template.label.htmlEscaped)</h2>
              <p>\(templateIntro.htmlEscaped)</p>
            </section>
            <section class="cards">\(cards)</section>
            <section class="charts">
              <div class="panel">
                <h2>Top Values</h2>
                \(barChart)
              </div>
              <div class="panel">
                <h2>Trend View</h2>
                \(trendChart)
              </div>
            </section>
            <section class="panel">
              <h2>Severity and Category Sections</h2>
              \(sections)
            </section>
            <table>
              <thead><tr>\(headerCells)</tr></thead>
              <tbody>\(tableRows)</tbody>
            </table>
            <section class="panel">
              <h2>Methodology</h2>
              <p>This report is generated from the configured endpoint template and the selected fields, dimensions, filters, date range, sort order, and row limit. REST and GraphQL templates are editable because tenant licensing, RBAC, field availability, and API rollout may vary.</p>
            </section>
            <footer>Generated by ZAnalytics. Review source data and Automation Hub documentation before operational or executive use.</footer>
          </main>
        </body>
        </html>
        """
    }

    private static func intro(for template: ReportPresentationTemplate, result: ReportResult) -> String {
        switch template {
        case .executiveSummary:
            return "This executive summary emphasizes outcomes, risk posture, and the most visible metrics from \(result.rows.count) returned rows."
        case .technicalDetail:
            return "This technical detail report preserves operational evidence, grouped findings, charts, and the full result table for validation."
        case .customerSuccessReview:
            return "This customer success review highlights adoption signals, recurring patterns, and follow-up areas for service and value discussions."
        }
    }

    private static func barChartHTML(for rows: [[String: ReportValue]]) -> String {
        let points = chartPoints(from: rows, limit: 7)
        guard !points.isEmpty else {
            return "<p>No numeric values were available for charting.</p>"
        }
        let maxValue = points.map(\.value).max() ?? 1
        return points.map { point in
            let width = max(5, min(100, Int((point.value / maxValue) * 100)))
            return """
            <div class="bar-row">
              <span>\(point.label.htmlEscaped)</span>
              <div class="bar-track"><span style="width: \(width)%"></span></div>
              <span>\(point.value.formatted(.number.precision(.fractionLength(0...0))))</span>
            </div>
            """
        }.joined(separator: "\n")
    }

    private static func trendChartSVG(for rows: [[String: ReportValue]]) -> String {
        let points = chartPoints(from: rows, limit: 10)
        guard points.count > 1 else {
            return "<p>No trend-ready numeric series was available.</p>"
        }
        let width = 640.0
        let height = 220.0
        let padding = 24.0
        let maxValue = max(points.map(\.value).max() ?? 1, 1)
        let coordinates = points.enumerated().map { index, point -> String in
            let x = padding + (Double(index) / Double(max(points.count - 1, 1))) * (width - padding * 2)
            let y = height - padding - (point.value / maxValue) * (height - padding * 2)
            return "\(x.formatted(.number.precision(.fractionLength(1)))),\(y.formatted(.number.precision(.fractionLength(1))))"
        }.joined(separator: " ")

        return """
        <svg role="img" aria-label="Trend line chart" viewBox="0 0 \(Int(width)) \(Int(height))" width="100%" height="220">
          <rect x="0" y="0" width="\(Int(width))" height="\(Int(height))" fill="#fbfcfd"></rect>
          <line x1="\(padding)" y1="\(height - padding)" x2="\(width - padding)" y2="\(height - padding)" stroke="#d5dce6"></line>
          <line x1="\(padding)" y1="\(padding)" x2="\(padding)" y2="\(height - padding)" stroke="#d5dce6"></line>
          <polyline points="\(coordinates)" fill="none" stroke="#1f8f7a" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"></polyline>
        </svg>
        """
    }

    private static func groupedSectionsHTML(for rows: [[String: ReportValue]]) -> String {
        guard let key = groupingKey(for: rows) else {
            return "<p>No severity or category field was detected in the returned rows.</p>"
        }
        let groups = Dictionary(grouping: rows) { row in
            row[key]?.description.isEmpty == false ? row[key]?.description ?? "Unspecified" : "Unspecified"
        }
        let items = groups.sorted { $0.key < $1.key }.map { group, rows in
            """
            <div class="section-item">
              <h3>\(key.htmlEscaped)</h3>
              <strong>\(group.htmlEscaped)</strong>
              <span>\(rows.count) rows</span>
            </div>
            """
        }.joined(separator: "\n")
        return "<div class=\"section-grid\">\(items)</div>"
    }

    private static func chartPoints(from rows: [[String: ReportValue]], limit: Int) -> [(label: String, value: Double)] {
        guard let numericKey = numericKey(for: rows) else {
            return []
        }
        let labelKey = labelKey(for: rows)
        return rows.prefix(limit).enumerated().compactMap { index, row in
            guard let value = row[numericKey]?.doubleValue else {
                return nil
            }
            let label = labelKey.flatMap { row[$0]?.description }.flatMap { $0.isEmpty ? nil : $0 } ?? "Row \(index + 1)"
            return (label, value)
        }
    }

    private static func numericKey(for rows: [[String: ReportValue]]) -> String? {
        let preferred = ["detections", "threat_count", "requests", "sessions", "blocked", "blocked_count", "users", "bandwidth_mb", "bytes", "experience_score", "users_impacted", "risk_score", "allowed_count"]
        let keys = Array(Set(rows.flatMap { $0.keys }))
        return preferred.first(where: { key in keys.contains(key) && rows.contains { $0[key]?.doubleValue != nil } })
            ?? keys.sorted().first(where: { key in rows.contains { $0[key]?.doubleValue != nil } })
    }

    private static func labelKey(for rows: [[String: ReportValue]]) -> String? {
        let preferred = ["day", "category", "severity", "threat_type", "application", "application_segment", "location", "risk_level", "action", "issue_type"]
        let keys = Set(rows.flatMap { $0.keys })
        return preferred.first(where: { keys.contains($0) })
    }

    private static func groupingKey(for rows: [[String: ReportValue]]) -> String? {
        let preferred = ["severity", "category", "risk_level", "action", "issue_type", "application", "location"]
        let keys = Set(rows.flatMap { $0.keys })
        return preferred.first(where: { keys.contains($0) })
    }
}

private extension ReportValue {
    var doubleValue: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }
}

extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    var fileSafe: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }.reduce("") { $0 + String($1) }
    }
}

extension Date {
    var exportStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: self)
    }
}
