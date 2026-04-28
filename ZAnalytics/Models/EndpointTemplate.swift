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
            transport: .graphql,
            pathTemplate: "/oneapi/analytics/web/v1/report",
            graphqlEndpointPath: "/zins/graphql",
            graphqlQuery: EndpointTemplate.webTrafficByLocationQuery,
            graphqlVariablesJSON: "{\"trafficUnit\":\"TRANSACTIONS\"}",
            notes: "Z-Insights GraphQL web traffic grouped by location. Requires OneAPI Z-Insights analytics permissions."
        ),
        EndpointTemplate(
            key: "threats",
            displayName: "Cybersecurity Analytics",
            category: "Cybersecurity",
            transport: .graphql,
            pathTemplate: "/oneapi/analytics/cybersecurity/v1/report",
            graphqlEndpointPath: "/zins/graphql",
            graphqlQuery: EndpointTemplate.cyberSecurityByLocationQuery,
            graphqlVariablesJSON: "{\"categorizeBy\":\"LOCATION_ID\"}",
            notes: "Z-Insights GraphQL cybersecurity incidents grouped by location. Requires OneAPI Z-Insights analytics permissions."
        ),
        EndpointTemplate(
            key: "saas",
            displayName: "SaaS Security / Shadow IT",
            category: "SaaS",
            transport: .graphql,
            pathTemplate: "/oneapi/analytics/saas/v1/report",
            graphqlEndpointPath: "/zins/graphql",
            graphqlQuery: EndpointTemplate.saasSecurityAppReportQuery,
            notes: "Z-Insights GraphQL CASB/SaaS app report. Requires SaaS Security analytics permissions."
        ),
        EndpointTemplate(
            key: "firewall",
            displayName: "Zero Trust Firewall",
            category: "Firewall",
            transport: .graphql,
            pathTemplate: "/oneapi/analytics/firewall/v1/report",
            graphqlEndpointPath: "/zins/graphql",
            graphqlQuery: EndpointTemplate.firewallByLocationQuery,
            notes: "Z-Insights GraphQL Zero Trust Firewall traffic grouped by location. Requires firewall analytics permissions."
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

    static let webTrafficByLocationQuery = """
    query WebTrafficByLocation($startTime: Long!, $endTime: Long!, $trafficUnit: WebTrafficUnits!, $limit: Int) {
      WEB_TRAFFIC {
        location(start_time: $startTime, end_time: $endTime, traffic_unit: $trafficUnit) {
          obfuscated
          entries(limit: $limit) {
            name
            total
          }
        }
      }
    }
    """

    static let cyberSecurityByLocationQuery = """
    query CyberSecurityByLocation($startTime: Long!, $endTime: Long!, $categorizeBy: IncidentsWithIdGroupBy!, $limit: Int) {
      CYBER_SECURITY {
        cyber_security_location(categorize_by: $categorizeBy, start_time: $startTime, end_time: $endTime) {
          obfuscated
          entries(limit: $limit) {
            id
            name
            total
          }
        }
      }
    }
    """

    static let saasSecurityAppReportQuery = """
    query CasbAppReport($startTime: Long!, $endTime: Long!, $limit: Int) {
      SAAS_SECURITY {
        casb_app(start_time: $startTime, end_time: $endTime) {
          obfuscated
          entries(limit: $limit) {
            name
            total
          }
        }
      }
    }
    """

    static let firewallByLocationQuery = """
    query FirewallByLocation($startTime: Long!, $endTime: Long!, $limit: Int) {
      ZERO_TRUST_FIREWALL {
        location_firewall(start_time: $startTime, end_time: $endTime) {
          obfuscated
          entries(limit: $limit) {
            name
            total
          }
        }
      }
    }
    """
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
