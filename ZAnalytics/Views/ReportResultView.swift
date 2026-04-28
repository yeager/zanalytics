import SwiftUI

struct ReportResultView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ResultToolbar()
            Divider()
            if let result = appState.latestResult {
                ResultContent(result: result)
            } else {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: t("No report yet", "Ingen rapport ännu"),
                    message: appState.preferences.mockModeEnabled
                        ? t("Run a canned report to see sample analytics data, summary cards, and exports.", "Kör en färdig rapport för att se exempeldata, sammanfattningskort och exporter.")
                        : t("Configure OneAPI settings, confirm endpoint paths, then run a report. Mock mode is available if you want to explore first.", "Konfigurera OneAPI-inställningar, bekräfta endpoint-sökvägar och kör sedan en rapport. Mockläge finns om du vill utforska först.")
                )
            }
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct ResultToolbar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Report Output", "Rapportutdata"))
                    .font(.headline)
                Text(t("Export JSON, CSV, HTML, PDF, or PowerPoint reports.", "Exportera rapporter som JSON, CSV, HTML, PDF eller PowerPoint."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker(t("HTML Template", "HTML-mall"), selection: $appState.selectedHTMLTemplate) {
                ForEach(ReportPresentationTemplate.allCases) { template in
                    Text(template.localizedLabel(language: appState.preferences.language)).tag(template)
                }
            }
            .frame(width: 230)
            .disabled(appState.latestResult == nil)
            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.label) {
                        _ = appState.exportLatestResult(as: format)
                    }
                }
            } label: {
                Label(t("Export", "Exportera"), systemImage: "square.and.arrow.up")
            }
            .disabled(appState.latestResult == nil)
        }
        .padding(16)
        .background(.background)
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct ResultContent: View {
    @EnvironmentObject private var appState: AppState
    let result: ReportResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localizedReportName)
                        .font(.title2.weight(.semibold))
                    Text("\(t("Generated", "Genererad")) \(result.generatedAt.formatted(date: .abbreviated, time: .shortened)) | \(result.dateRangeDescription)")
                        .foregroundStyle(.secondary)
                    Text("\(t("Request ID", "Begärans-ID")): \(result.requestID)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(result.summaryCards) { card in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(card.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(card.value)
                                .font(.title2.weight(.semibold))
                            Text(card.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor))
                        )
                    }
                }

                if result.rows.isEmpty {
                    EmptyStateView(systemImage: "tablecells", title: t("No rows returned", "Inga rader returnerades"), message: t("The endpoint responded, but there were no tabular rows to display. Check filters, date range, and tenant permissions.", "Endpointen svarade, men det fanns inga tabellrader att visa. Kontrollera filter, datumintervall och tenant-behörigheter."))
                        .frame(minHeight: 240)
                } else {
                    ResultTable(rows: result.rows)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var localizedReportName: String {
        guard let report = appState.reportCatalog.first(where: { $0.name == result.reportName || ReportLocalization.name(for: $0, language: .swedish) == result.reportName }) else {
            return result.reportName
        }
        return ReportLocalization.name(for: report, language: appState.preferences.language)
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct ResultTable: View {
    @EnvironmentObject private var appState: AppState
    let rows: [[String: ReportValue]]

    private var headers: [String] {
        Array(Set(rows.flatMap { $0.keys })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Rows", "Rader", language: appState.preferences.language))
                .font(.headline)
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(headers, id: \.self) { header in
                            CellText(header, isHeader: true)
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(headers, id: \.self) { header in
                                CellText(row[header]?.description ?? "", isHeader: false)
                            }
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                )
            }
        }
    }
}

private struct CellText: View {
    let text: String
    let isHeader: Bool

    init(_ text: String, isHeader: Bool) {
        self.text = text
        self.isHeader = isHeader
    }

    var body: some View {
        Text(text)
            .font(isHeader ? .caption.weight(.semibold) : .caption)
            .lineLimit(2)
            .frame(width: 150, alignment: .leading)
            .frame(minHeight: 34)
            .padding(.horizontal, 10)
            .background(isHeader ? Color(nsColor: .underPageBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 0.5)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

struct EmptyInlineView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
