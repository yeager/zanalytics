import Foundation

struct EndpointTemplate: Codable, Identifiable, Hashable {
    var id: UUID
    var key: String
    var displayName: String
    var category: String
    var method: HTTPMethod
    var pathTemplate: String
    var notes: String

    init(
        id: UUID = UUID(),
        key: String,
        displayName: String,
        category: String,
        method: HTTPMethod = .post,
        pathTemplate: String,
        notes: String
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.category = category
        self.method = method
        self.pathTemplate = pathTemplate
        self.notes = notes
    }

    static let defaults: [EndpointTemplate] = [
        EndpointTemplate(
            key: "web",
            displayName: "Web Traffic Analytics",
            category: "Web",
            pathTemplate: "/oneapi/analytics/web/v1/report",
            notes: "Placeholder for web traffic analytics. Confirm the tenant-specific path in Zscaler OneAPI docs or your admin portal."
        ),
        EndpointTemplate(
            key: "threats",
            displayName: "Cybersecurity Analytics",
            category: "Cybersecurity",
            pathTemplate: "/oneapi/analytics/cybersecurity/v1/report",
            notes: "Placeholder for threat and security analytics. RBAC and licensed features may change available fields."
        ),
        EndpointTemplate(
            key: "saas",
            displayName: "SaaS Security / Shadow IT",
            category: "SaaS",
            pathTemplate: "/oneapi/analytics/saas/v1/report",
            notes: "Placeholder for SaaS security and Shadow IT reporting."
        ),
        EndpointTemplate(
            key: "firewall",
            displayName: "Zero Trust Firewall",
            category: "Firewall",
            pathTemplate: "/oneapi/analytics/firewall/v1/report",
            notes: "Placeholder for Zero Trust Firewall and network activity reporting."
        ),
        EndpointTemplate(
            key: "zpa",
            displayName: "ZPA Access",
            category: "Private Access",
            pathTemplate: "/oneapi/analytics/zpa/v1/report",
            notes: "Placeholder for ZPA access activity. Some tenants may expose this through product-specific APIs."
        ),
        EndpointTemplate(
            key: "zdx",
            displayName: "ZDX Experience",
            category: "Digital Experience",
            pathTemplate: "/oneapi/analytics/zdx/v1/report",
            notes: "Placeholder for ZDX experience summaries. Availability depends on ZDX licensing and RBAC."
        )
    ]
}

enum HTTPMethod: String, Codable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"

    var id: String { rawValue }
}
