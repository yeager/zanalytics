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
    func export(_ result: ReportResult, as format: ExportFormat) throws -> URL {
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
            try HTMLReportRenderer.html(for: result).write(to: url, atomically: true, encoding: .utf8)
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
    static func html(for result: ReportResult) -> String {
        let headers = Array(Set(result.rows.flatMap { $0.keys })).sorted()
        let maxCardValue = result.summaryCards.compactMap { Double($0.value.replacingOccurrences(of: ",", with: "")) }.max() ?? 1
        let cards = result.summaryCards.map { card in
            let numeric = Double(card.value.replacingOccurrences(of: ",", with: "")) ?? 0
            let width = max(8, min(100, Int((numeric / maxCardValue) * 100)))
            return """
            <section class="card">
              <h2>\(card.title.htmlEscaped)</h2>
              <strong>\(card.value.htmlEscaped)</strong>
              <p>\(card.detail.htmlEscaped)</p>
              <div class="bar"><span style="width: \(width)%"></span></div>
            </section>
            """
        }.joined(separator: "\n")

        let tableRows = result.rows.map { row in
            let cells = headers.map { "<td>\((row[$0]?.description ?? "").htmlEscaped)</td>" }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        let headerCells = headers.map { "<th>\($0.htmlEscaped)</th>" }.joined()

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(result.reportName.htmlEscaped)</title>
          <style>
            :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #17202a; }
            body { margin: 0; background: #f7f8fa; }
            main { max-width: 1120px; margin: 0 auto; padding: 36px 28px 60px; }
            header { border-bottom: 1px solid #d9dee7; margin-bottom: 24px; padding-bottom: 18px; }
            h1 { margin: 0 0 8px; font-size: 30px; }
            .meta { color: #5c6675; margin: 4px 0; }
            .notice { background: #fff7df; border: 1px solid #ead28a; padding: 12px 14px; border-radius: 8px; margin: 18px 0; }
            .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; margin: 22px 0; }
            .card { background: white; border: 1px solid #dfe4ec; border-radius: 8px; padding: 16px; }
            .card h2 { font-size: 13px; color: #5c6675; margin: 0 0 8px; text-transform: uppercase; letter-spacing: .04em; }
            .card strong { font-size: 28px; }
            .card p { color: #5c6675; margin: 8px 0 12px; }
            .bar { height: 8px; background: #e9edf4; border-radius: 999px; overflow: hidden; }
            .bar span { display: block; height: 100%; background: #2864d8; }
            table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #dfe4ec; }
            th, td { padding: 10px 12px; border-bottom: 1px solid #edf0f5; text-align: left; font-size: 13px; }
            th { background: #eef2f8; color: #374151; }
            @media print { body { background: white; } main { padding: 0; } .notice { break-inside: avoid; } }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>\(result.reportName.htmlEscaped)</h1>
              <p class="meta">Generated \(result.generatedAt.formatted(date: .abbreviated, time: .shortened)) for \(result.dateRangeDescription.htmlEscaped)</p>
              <p class="meta">Endpoint: \(result.endpointPath.htmlEscaped) | Request ID: \(result.requestID.htmlEscaped)</p>
            </header>
            <p class="notice">ZAnalytics is an unofficial helper and is not affiliated with, endorsed by, or sponsored by Zscaler. Validate endpoint paths, RBAC, and report semantics against your tenant before using this output operationally.</p>
            <section class="cards">\(cards)</section>
            <table>
              <thead><tr>\(headerCells)</tr></thead>
              <tbody>\(tableRows)</tbody>
            </table>
          </main>
        </body>
        </html>
        """
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
