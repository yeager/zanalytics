import Foundation

struct EndpointTemplate: Codable, Identifiable, Hashable {
    var id: UUID
    var key: String
    var displayName: String
    var category: String
    var transport: APITransport
    var method: HTTPMethod
    var pathTemplate: String
    var graphqlEndpointPath: String
    var graphqlQuery: String
    var graphqlVariablesJSON: String
    var notes: String

    init(
        id: UUID = UUID(),
        key: String,
        displayName: String,
        category: String,
        transport: APITransport = .rest,
        method: HTTPMethod = .post,
        pathTemplate: String,
        graphqlEndpointPath: String = "/oneapi/graphql",
        graphqlQuery: String = "",
        graphqlVariablesJSON: String = "",
        notes: String
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.category = category
        self.transport = transport
        self.method = method
        self.pathTemplate = pathTemplate
        self.graphqlEndpointPath = graphqlEndpointPath
        self.graphqlQuery = graphqlQuery
        self.graphqlVariablesJSON = graphqlVariablesJSON
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case displayName
        case category
        case transport
        case method
        case pathTemplate
        case graphqlEndpointPath
        case graphqlQuery
        case graphqlVariablesJSON
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        key = try container.decode(String.self, forKey: .key)
        displayName = try container.decode(String.self, forKey: .displayName)
        category = try container.decode(String.self, forKey: .category)
        transport = try container.decodeIfPresent(APITransport.self, forKey: .transport) ?? .rest
        method = try container.decodeIfPresent(HTTPMethod.self, forKey: .method) ?? .post
        pathTemplate = try container.decode(String.self, forKey: .pathTemplate)
        graphqlEndpointPath = try container.decodeIfPresent(String.self, forKey: .graphqlEndpointPath) ?? "/oneapi/graphql"
        graphqlQuery = try container.decodeIfPresent(String.self, forKey: .graphqlQuery) ?? ""
        graphqlVariablesJSON = try container.decodeIfPresent(String.self, forKey: .graphqlVariablesJSON) ?? ""
        notes = try container.decode(String.self, forKey: .notes)
    }

    static let defaults: [EndpointTemplate] = [
        EndpointTemplate(
            key: "web",
            displayName: "Web Traffic Analytics",
            category: "Web",
            pathTemplate: "/oneapi/analytics/web/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "webAnalytics"),
            notes: "Placeholder for web traffic analytics. REST and GraphQL paths may vary by tenant rollout; confirm in Automation Hub or your admin portal."
        ),
        EndpointTemplate(
            key: "threats",
            displayName: "Cybersecurity Analytics",
            category: "Cybersecurity",
            pathTemplate: "/oneapi/analytics/cybersecurity/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "cybersecurityAnalytics"),
            notes: "Placeholder for threat and security analytics. RBAC, licensed features, and REST vs GraphQL availability may change available fields."
        ),
        EndpointTemplate(
            key: "saas",
            displayName: "SaaS Security / Shadow IT",
            category: "SaaS",
            pathTemplate: "/oneapi/analytics/saas/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "saasAnalytics"),
            notes: "Placeholder for SaaS security and Shadow IT reporting. Confirm whether REST or GraphQL is enabled for your tenant."
        ),
        EndpointTemplate(
            key: "firewall",
            displayName: "Zero Trust Firewall",
            category: "Firewall",
            pathTemplate: "/oneapi/analytics/firewall/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "firewallAnalytics"),
            notes: "Placeholder for Zero Trust Firewall and network activity reporting. API shape may differ during tenant rollout."
        ),
        EndpointTemplate(
            key: "zpa",
            displayName: "ZPA Access",
            category: "Private Access",
            pathTemplate: "/oneapi/analytics/zpa/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "zpaAnalytics"),
            notes: "Placeholder for ZPA access activity. Some tenants may expose this through product-specific APIs or GraphQL fields."
        ),
        EndpointTemplate(
            key: "zdx",
            displayName: "ZDX Experience",
            category: "Digital Experience",
            pathTemplate: "/oneapi/analytics/zdx/v1/report",
            graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "zdxAnalytics"),
            notes: "Placeholder for ZDX experience summaries. Availability depends on ZDX licensing, RBAC, and API rollout."
        )
    ]

    static func defaultGraphQLQuery(operationName: String) -> String {
        """
        query ZAnalyticsReport($dateRange: DateRangeInput, $fields: [String!], $dimensions: [String!], $filters: [ReportFilterInput!], $sort: String, $limit: Int) {
          \(operationName)(dateRange: $dateRange, fields: $fields, dimensions: $dimensions, filters: $filters, sort: $sort, limit: $limit) {
            rows
          }
        }
        """
    }
}

enum HTTPMethod: String, Codable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"

    var id: String { rawValue }
}

enum APITransport: String, Codable, CaseIterable, Identifiable {
    case rest = "REST"
    case graphql = "GraphQL"

    var id: String { rawValue }
}
