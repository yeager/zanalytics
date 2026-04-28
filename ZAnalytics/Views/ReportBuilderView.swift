import SwiftUI

struct ReportBuilderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReportDescriptionView(report: appState.selectedReport)
                DateRangeSection()
                FieldsSection()
                FiltersSection()
                PresentationSection()
                RunSection()
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ReportDescriptionView: View {
    @EnvironmentObject private var appState: AppState
    let report: ReportDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ReportLocalization.name(for: report, language: appState.preferences.language))
                .font(.title2.weight(.semibold))
            Text(ReportLocalization.summary(for: report, language: appState.preferences.language))
                .foregroundStyle(.secondary)
            Label("\(t("Default category", "Standardkategori")): \(ReportLocalization.category(report.category, language: appState.preferences.language))", systemImage: "tag")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ReportLocalization.guidance(for: report, language: appState.preferences.language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct DateRangeSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox(t("Date Range", "Datumintervall")) {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker(t("From", "Från"), selection: $appState.reportRequest.startDate, displayedComponents: [.date])
                DatePicker(t("To", "Till"), selection: $appState.reportRequest.endDate, displayedComponents: [.date])
                if appState.reportRequest.endDate < appState.reportRequest.startDate {
                    Label(t("End date must be after start date.", "Slutdatum måste vara efter startdatum."), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.top, 4)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct FieldsSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox(t("Fields and Dimensions", "Fält och dimensioner")) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Fields", "Fält"))
                        .font(.caption.weight(.semibold))
                    TextField("requests, blocked, users", text: $appState.reportRequest.fieldsText, axis: .vertical)
                        .lineLimit(2...5)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Dimensions", "Dimensioner"))
                        .font(.caption.weight(.semibold))
                    TextField("day, location, category", text: $appState.reportRequest.dimensionsText, axis: .vertical)
                        .lineLimit(2...5)
                }
                HStack {
                    TextField(t("Sort", "Sortering"), text: $appState.reportRequest.sort)
                    Stepper(value: $appState.reportRequest.limit, in: 1...10_000, step: 25) {
                        Text("\(t("Limit", "Gräns")): \(appState.reportRequest.limit)")
                    }
                }
                Text(t("Use comma-separated field names from your tenant documentation. Prefix sort with '-' for descending where supported.", "Använd kommaseparerade fältnamn från tenant-dokumentationen. Prefixa sortering med '-' för fallande ordning där det stöds."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct FiltersSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox(t("Filters", "Filter")) {
            VStack(alignment: .leading, spacing: 10) {
                if appState.reportRequest.filters.isEmpty {
                    EmptyInlineView(text: t("No filters. Add one to narrow the report by user, location, app, action, severity, or any supported field.", "Inga filter. Lägg till ett för att avgränsa rapporten efter användare, plats, app, åtgärd, allvarlighetsgrad eller annat fält som stöds."))
                }

                ForEach($appState.reportRequest.filters) { $filter in
                    HStack {
                        TextField(t("Field", "Fält"), text: $filter.field)
                        TextField(t("Operation", "Operation"), text: $filter.operation)
                            .frame(width: 110)
                        TextField(t("Value", "Värde"), text: $filter.value)
                        Button {
                            appState.reportRequest.filters.removeAll { $0.id == filter.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help(t("Remove filter", "Ta bort filter"))
                    }
                }

                Button {
                    appState.reportRequest.filters.append(ReportFilter(field: "", operation: "equals", value: ""))
                } label: {
                    Label(t("Add Filter", "Lägg till filter"), systemImage: "plus")
                }
            }
            .padding(.top, 4)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct PresentationSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox(t("HTML Presentation", "HTML-presentation")) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(t("Template", "Mall"), selection: $appState.selectedHTMLTemplate) {
                    ForEach(ReportPresentationTemplate.allCases) { template in
                        Text(template.localizedLabel(language: appState.preferences.language)).tag(template)
                    }
                }
                Text(appState.selectedHTMLTemplate.localizedShortDescription(language: appState.preferences.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct RunSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let template = appState.endpointTemplates.first(where: { $0.key == appState.reportRequest.endpointKey }) {
                GroupBox("Endpoint") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.displayName)
                            .font(.headline)
                        Text(endpointDescription(template))
                            .font(.system(.body, design: .monospaced))
                        Text(template.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            } else {
                Label(t("No endpoint template matches this report.", "Ingen endpoint-mall matchar rapporten."), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Button {
                Task { await appState.runSelectedReport() }
            } label: {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text(t("Running", "Kör"))
                } else {
                    Label(t("Run Report", "Kör rapport"), systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.isLoading || appState.reportRequest.endDate < appState.reportRequest.startDate)

            if let status = appState.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }

    private func endpointDescription(_ template: EndpointTemplate) -> String {
        switch template.transport {
        case .rest:
            return "\(template.transport.rawValue) \(template.method.rawValue) \(template.pathTemplate)"
        case .graphql:
            return "\(template.transport.rawValue) POST \(template.graphqlEndpointPath)"
        }
    }
}
