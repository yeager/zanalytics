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
                RunSection()
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ReportDescriptionView: View {
    let report: ReportDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.name)
                .font(.title2.weight(.semibold))
            Text(report.summary)
                .foregroundStyle(.secondary)
            Label("Default category: \(report.category)", systemImage: "tag")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DateRangeSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox("Date Range") {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker("From", selection: $appState.reportRequest.startDate, displayedComponents: [.date])
                DatePicker("To", selection: $appState.reportRequest.endDate, displayedComponents: [.date])
                if appState.reportRequest.endDate < appState.reportRequest.startDate {
                    Label("End date must be after start date.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct FieldsSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox("Fields and Dimensions") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Fields")
                        .font(.caption.weight(.semibold))
                    TextField("requests, blocked, users", text: $appState.reportRequest.fieldsText, axis: .vertical)
                        .lineLimit(2...5)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dimensions")
                        .font(.caption.weight(.semibold))
                    TextField("day, location, category", text: $appState.reportRequest.dimensionsText, axis: .vertical)
                        .lineLimit(2...5)
                }
                HStack {
                    TextField("Sort", text: $appState.reportRequest.sort)
                    Stepper(value: $appState.reportRequest.limit, in: 1...10_000, step: 25) {
                        Text("Limit: \(appState.reportRequest.limit)")
                    }
                }
                Text("Use comma-separated field names from your tenant documentation. Prefix sort with '-' for descending where supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

private struct FiltersSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GroupBox("Filters") {
            VStack(alignment: .leading, spacing: 10) {
                if appState.reportRequest.filters.isEmpty {
                    EmptyInlineView(text: "No filters. Add one to narrow the report by user, location, app, action, severity, or any supported field.")
                }

                ForEach($appState.reportRequest.filters) { $filter in
                    HStack {
                        TextField("Field", text: $filter.field)
                        TextField("Operation", text: $filter.operation)
                            .frame(width: 110)
                        TextField("Value", text: $filter.value)
                        Button {
                            appState.reportRequest.filters.removeAll { $0.id == filter.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove filter")
                    }
                }

                Button {
                    appState.reportRequest.filters.append(ReportFilter(field: "", operation: "equals", value: ""))
                } label: {
                    Label("Add Filter", systemImage: "plus")
                }
            }
            .padding(.top, 4)
        }
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
                        Text("\(template.method.rawValue) \(template.pathTemplate)")
                            .font(.system(.body, design: .monospaced))
                        Text(template.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            } else {
                Label("No endpoint template matches this report.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Button {
                Task { await appState.runSelectedReport() }
            } label: {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Running")
                } else {
                    Label("Run Report", systemImage: "play.fill")
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
}
