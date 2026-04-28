import Foundation

enum MockDataProvider {
    static func result(for request: ReportRequest, definition: ReportDefinition) -> ReportResult {
        let rows = sampleRows(for: definition, limit: min(request.limit, 12))
        let cards = summaryCards(for: definition, rows: rows)
        let rawJSONData = try? JSONEncoder().encode(rows)
        let rawJSON = rawJSONData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return ReportResult(
            reportName: definition.name,
            endpointPath: EndpointTemplate.defaults.first(where: { $0.key == definition.endpointKey })?.pathTemplate ?? "/mock",
            requestID: "mock-\(UUID().uuidString)",
            dateRangeDescription: "\(request.startDate.formatted(date: .abbreviated, time: .omitted)) - \(request.endDate.formatted(date: .abbreviated, time: .omitted))",
            summaryCards: cards,
            rows: rows,
            rawJSON: rawJSON,
            presentationTemplate: request.presentationTemplate
        )
    }

    private static func sampleRows(for definition: ReportDefinition, limit: Int) -> [[String: ReportValue]] {
        let locations = ["New York", "London", "Stockholm", "Tokyo", "Sydney", "Toronto"]
        let apps = ["Salesforce", "Microsoft 365", "Slack", "GitHub", "Box", "Zoom"]
        let threats = ["Phishing", "Malware", "C2", "Riskware", "Credential Theft", "Suspicious Script"]
        let categories = ["Business", "Collaboration", "Cloud Storage", "AI Tools", "News", "Unknown"]

        return (0..<limit).map { index in
            var row: [String: ReportValue] = [
                "day": .string(Calendar.current.date(byAdding: .day, value: -index, to: Date())?.formatted(date: .abbreviated, time: .omitted) ?? ""),
                "location": .string(locations[index % locations.count]),
                "requests": .int(12_000 - index * 613),
                "blocked": .int(420 + index * 18),
                "allowed": .int(8_300 - index * 210),
                "users": .int(140 + index * 7)
            ]

            switch definition.endpointKey {
            case "saas":
                row["application"] = .string(apps[index % apps.count])
                row["risk_score"] = .int(91 - index * 6)
                row["risk_level"] = .string(index < 3 ? "High" : "Medium")
                row["sanctioned"] = .bool(index % 3 == 0)
            case "threats":
                row["threat_type"] = .string(threats[index % threats.count])
                row["severity"] = .string(index < 2 ? "Critical" : index < 5 ? "High" : "Medium")
                row["detections"] = .int(860 - index * 47)
                row["threat_count"] = .int(930 - index * 51)
                row["blocked_count"] = .int(900 - index * 44)
                row["top_category"] = .string(categories[index % categories.count])
                row["top_location"] = .string(locations[index % locations.count])
            case "firewall":
                row["sessions"] = .int(31_000 - index * 1200)
                row["bytes"] = .int(900_000_000 - index * 38_000_000)
                row["application"] = .string(apps[index % apps.count])
                row["destination_port"] = .int([443, 80, 22, 8443, 53][index % 5])
                row["action"] = .string(index % 4 == 0 ? "Blocked" : "Allowed")
            case "zpa":
                row["application_segment"] = .string(["ERP", "Git", "HR Portal", "Finance", "Admin SSH"][index % 5])
                row["sessions"] = .int(4_200 - index * 155)
                row["denied"] = .int(40 + index * 8)
                row["connector_group"] = .string(["US-East", "EU-West", "APAC"][index % 3])
            case "zdx":
                row["experience_score"] = .int(94 - index * 3)
                row["users_impacted"] = .int(5 + index * 4)
                row["application"] = .string(apps[index % apps.count])
                row["issue_type"] = .string(["Latency", "DNS", "Device", "Wi-Fi"][index % 4])
            default:
                row["category"] = .string(categories[index % categories.count])
                row["bandwidth_mb"] = .int(8_900 - index * 480)
            }

            return row
        }
    }

    private static func summaryCards(for definition: ReportDefinition, rows: [[String: ReportValue]]) -> [SummaryCard] {
        switch definition.endpointKey {
        case "threats":
            return [
                SummaryCard(title: "Blocked Threats", value: "4,812", detail: "Mock detections blocked"),
                SummaryCard(title: "Critical Items", value: "19", detail: "Needs review"),
                SummaryCard(title: "Top Source", value: "London", detail: "By event volume")
            ]
        case "zdx":
            return [
                SummaryCard(title: "Experience", value: "87", detail: "Average score"),
                SummaryCard(title: "Users Impacted", value: "73", detail: "Across sampled apps"),
                SummaryCard(title: "Top Issue", value: "Latency", detail: "Most common cause")
            ]
        default:
            return OneAPIResponseParser.summaryCards(from: rows)
        }
    }
}
