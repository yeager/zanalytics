import Foundation

struct ReportDefinition: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var endpointKey: String
    var summary: String
    var defaultPresentationTemplate: ReportPresentationTemplate
    var templateGuidance: String
    var defaultFields: [String]
    var defaultDimensions: [String]
    var defaultFilters: [ReportFilter]
    var defaultSort: String
    var defaultLimit: Int

    init(
        id: String,
        name: String,
        category: String,
        endpointKey: String,
        summary: String,
        defaultPresentationTemplate: ReportPresentationTemplate = .technicalDetail,
        templateGuidance: String = "Use Technical Detail for validation and handoff; switch to Executive Summary or Customer Success Review when the audience needs less raw detail.",
        defaultFields: [String],
        defaultDimensions: [String],
        defaultFilters: [ReportFilter],
        defaultSort: String,
        defaultLimit: Int
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.endpointKey = endpointKey
        self.summary = summary
        self.defaultPresentationTemplate = defaultPresentationTemplate
        self.templateGuidance = templateGuidance
        self.defaultFields = defaultFields
        self.defaultDimensions = defaultDimensions
        self.defaultFilters = defaultFilters
        self.defaultSort = defaultSort
        self.defaultLimit = defaultLimit
    }
}

struct ReportFilter: Codable, Identifiable, Hashable {
    var id = UUID()
    var field: String
    var operation: String
    var value: String
}

struct ReportRequest: Codable, Equatable {
    var reportID: String
    var reportName: String
    var endpointKey: String
    var startDate: Date
    var endDate: Date
    var fieldsText: String
    var dimensionsText: String
    var filters: [ReportFilter]
    var sort: String
    var limit: Int
    var presentationTemplate: ReportPresentationTemplate

    init(definition: ReportDefinition) {
        self.reportID = definition.id
        self.reportName = definition.name
        self.endpointKey = definition.endpointKey
        self.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        self.endDate = Date()
        self.fieldsText = definition.defaultFields.joined(separator: ", ")
        self.dimensionsText = definition.defaultDimensions.joined(separator: ", ")
        self.filters = definition.defaultFilters
        self.sort = definition.defaultSort
        self.limit = definition.defaultLimit
        self.presentationTemplate = definition.defaultPresentationTemplate
    }

    var fields: [String] {
        fieldsText.csvTokens
    }

    var dimensions: [String] {
        dimensionsText.csvTokens
    }

    func payload() -> [String: Any] {
        [
            "report": reportID,
            "name": reportName,
            "dateRange": [
                "from": ISO8601DateFormatter.zanalytics.string(from: startDate),
                "to": ISO8601DateFormatter.zanalytics.string(from: endDate)
            ],
            "fields": fields,
            "dimensions": dimensions,
            "filters": filters.map {
                ["field": $0.field, "operation": $0.operation, "value": $0.value]
            },
            "sort": sort,
            "limit": limit
        ]
    }
}

struct ReportResult: Codable, Identifiable, Equatable {
    var id: UUID
    var reportName: String
    var endpointPath: String
    var generatedAt: Date
    var requestID: String
    var dateRangeDescription: String
    var summaryCards: [SummaryCard]
    var rows: [[String: ReportValue]]
    var rawJSON: String
    var presentationTemplate: ReportPresentationTemplate

    init(
        id: UUID = UUID(),
        reportName: String,
        endpointPath: String,
        generatedAt: Date = Date(),
        requestID: String,
        dateRangeDescription: String,
        summaryCards: [SummaryCard],
        rows: [[String: ReportValue]],
        rawJSON: String,
        presentationTemplate: ReportPresentationTemplate = .technicalDetail
    ) {
        self.id = id
        self.reportName = reportName
        self.endpointPath = endpointPath
        self.generatedAt = generatedAt
        self.requestID = requestID
        self.dateRangeDescription = dateRangeDescription
        self.summaryCards = summaryCards
        self.rows = rows
        self.rawJSON = rawJSON
        self.presentationTemplate = presentationTemplate
    }
}

struct SummaryCard: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var value: String
    var detail: String
}

enum ReportValue: Codable, Hashable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string((try? container.decode(String.self)) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var description: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return value.formatted(.number.precision(.fractionLength(0...2)))
        case .bool(let value): return value ? "true" : "false"
        case .null: return ""
        }
    }
}

enum ReportCatalog {
    static let defaults: [ReportDefinition] = [
        ReportDefinition(
            id: "executive-security-summary",
            name: "Executive Security Summary",
            category: "Executive",
            endpointKey: "threats",
            summary: "Board-friendly view of blocked threats, risky destinations, affected users, and policy outcomes.",
            defaultPresentationTemplate: .executiveSummary,
            templateGuidance: "Best exported as Executive Summary with KPI cards, severity callouts, and a compact evidence table.",
            defaultFields: ["threat_count", "blocked_count", "allowed_count", "top_category", "top_location"],
            defaultDimensions: ["day", "location"],
            defaultFilters: [],
            defaultSort: "-threat_count",
            defaultLimit: 100
        ),
        ReportDefinition(
            id: "web-usage",
            name: "Web Usage",
            category: "Web",
            endpointKey: "web",
            summary: "Shows top web categories, bandwidth, users, locations, and policy actions for usage reviews.",
            defaultPresentationTemplate: .customerSuccessReview,
            templateGuidance: "Customer Success Review works well for usage adoption, policy outcomes, and category trends.",
            defaultFields: ["requests", "bandwidth_mb", "blocked", "allowed", "category"],
            defaultDimensions: ["category", "location"],
            defaultFilters: [],
            defaultSort: "-requests",
            defaultLimit: 250
        ),
        ReportDefinition(
            id: "saas-shadow-it",
            name: "SaaS / Shadow IT",
            category: "SaaS",
            endpointKey: "saas",
            summary: "Highlights discovered SaaS apps, risk levels, user adoption, and unsanctioned usage signals.",
            defaultPresentationTemplate: .customerSuccessReview,
            templateGuidance: "Use Customer Success Review for adoption and governance conversations; switch to Technical Detail for app-by-app remediation.",
            defaultFields: ["application", "risk_score", "users", "requests", "sanctioned"],
            defaultDimensions: ["application", "risk_level"],
            defaultFilters: [],
            defaultSort: "-risk_score",
            defaultLimit: 200
        ),
        ReportDefinition(
            id: "threat-overview",
            name: "Threat Overview",
            category: "Cybersecurity",
            endpointKey: "threats",
            summary: "Operational view of malware, phishing, C2, and other detections grouped by severity and action.",
            defaultPresentationTemplate: .technicalDetail,
            templateGuidance: "Technical Detail keeps severity groups and row-level evidence prominent for security operations.",
            defaultFields: ["threat_type", "severity", "detections", "blocked", "users"],
            defaultDimensions: ["threat_type", "severity"],
            defaultFilters: [],
            defaultSort: "-detections",
            defaultLimit: 250
        ),
        ReportDefinition(
            id: "firewall-network-activity",
            name: "Firewall / Network Activity",
            category: "Firewall",
            endpointKey: "firewall",
            summary: "Summarizes Zero Trust Firewall sessions by application, port, action, location, and volume.",
            defaultPresentationTemplate: .technicalDetail,
            templateGuidance: "Technical Detail is the safest default for network activity because ports, applications, and actions need traceability.",
            defaultFields: ["sessions", "bytes", "application", "destination_port", "action"],
            defaultDimensions: ["application", "action"],
            defaultFilters: [],
            defaultSort: "-sessions",
            defaultLimit: 250
        ),
        ReportDefinition(
            id: "zpa-access-activity",
            name: "ZPA Access Activity",
            category: "Private Access",
            endpointKey: "zpa",
            summary: "Tracks private app access, users, connectors, policy actions, and denied attempts.",
            defaultPresentationTemplate: .customerSuccessReview,
            templateGuidance: "Customer Success Review highlights adoption, denied access, and connector/application patterns for service reviews.",
            defaultFields: ["application_segment", "users", "sessions", "denied", "connector_group"],
            defaultDimensions: ["application_segment", "connector_group"],
            defaultFilters: [],
            defaultSort: "-sessions",
            defaultLimit: 200
        ),
        ReportDefinition(
            id: "zdx-experience-summary",
            name: "ZDX Experience Summary",
            category: "Digital Experience",
            endpointKey: "zdx",
            summary: "Summarizes user experience scores, device health, application experience, and network issues.",
            defaultPresentationTemplate: .executiveSummary,
            templateGuidance: "Executive Summary keeps experience score, impacted users, and trend signals visible for leadership review.",
            defaultFields: ["experience_score", "users_impacted", "application", "issue_type", "location"],
            defaultDimensions: ["application", "location"],
            defaultFilters: [],
            defaultSort: "experience_score",
            defaultLimit: 150
        )
    ]
}

enum ReportPresentationTemplate: String, Codable, CaseIterable, Identifiable {
    case executiveSummary
    case technicalDetail
    case customerSuccessReview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .executiveSummary: return "Executive Summary"
        case .technicalDetail: return "Technical Detail"
        case .customerSuccessReview: return "Customer Success Review"
        }
    }

    var shortDescription: String {
        switch self {
        case .executiveSummary:
            return "Outcome-focused narrative, KPI cards, and concise evidence."
        case .technicalDetail:
            return "Operational detail with severity/category grouping and full rows."
        case .customerSuccessReview:
            return "Adoption, value, trend, and follow-up sections for service reviews."
        }
    }
}

extension String {
    var csvTokens: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension ISO8601DateFormatter {
    static let zanalytics: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
