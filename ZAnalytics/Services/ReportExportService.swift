import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportFormat: CaseIterable, Identifiable {
    case json
    case csv
    case html
    case pdf
    case pptx

    var id: String { extensionName }

    var label: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .html: return "HTML"
        case .pdf: return "PDF"
        case .pptx: return "PowerPoint (.pptx)"
        }
    }

    var extensionName: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .html: return "html"
        case .pdf: return "pdf"
        case .pptx: return "pptx"
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
        case .pdf:
            try PDFReportRenderer.write(result, template: template ?? result.presentationTemplate, to: url)
        case .pptx:
            try PowerPointReportRenderer.write(result, template: template ?? result.presentationTemplate, to: url)
        }
        return url
    }
}

enum ExportError: LocalizedError {
    case cancelled
    case renderingFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Export cancelled."
        case .renderingFailed(let message): return message
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

enum PDFReportRenderer {
    static func write(_ result: ReportResult, template: ReportPresentationTemplate, to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595) // A4 landscape, points.
        let margin: CGFloat = 42
        let contentWidth = pageRect.width - margin * 2
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.28, alpha: 1)
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.26, alpha: 1)
        ]
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ExportError.renderingFailed("Could not create PDF context.")
        }

        func beginPage() -> CGFloat {
            context.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1).setFill()
            pageRect.fill()
            return pageRect.height - margin
        }

        func endPage() {
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        func drawText(_ text: String, at y: inout CGFloat, attributes: [NSAttributedString.Key: Any], maxHeight: CGFloat = 72) {
            let rect = CGRect(x: margin, y: y - maxHeight, width: contentWidth, height: maxHeight)
            NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
            y -= min(maxHeight, NSString(string: text).boundingRect(with: CGSize(width: contentWidth, height: maxHeight), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).height + 10)
        }

        var y = beginPage()
        let hero = CGRect(x: margin, y: y - 92, width: contentWidth, height: 92)
        NSColor(calibratedRed: 0.07, green: 0.20, blue: 0.30, alpha: 1).setFill()
        NSBezierPath(roundedRect: hero, xRadius: 8, yRadius: 8).fill()
        NSString(string: result.reportName).draw(with: hero.insetBy(dx: 20, dy: 20), options: [.usesLineFragmentOrigin], attributes: titleAttributes)
        NSString(string: "\(template.label) • Generated \(result.generatedAt.formatted(date: .abbreviated, time: .shortened)) • \(result.dateRangeDescription)").draw(with: CGRect(x: hero.minX + 20, y: hero.minY + 16, width: hero.width - 40, height: 18), options: [.usesLineFragmentOrigin], attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor(calibratedRed: 0.80, green: 0.93, blue: 0.93, alpha: 1)])
        y -= 116

        drawText("Executive summary", at: &y, attributes: headingAttributes, maxHeight: 24)
        drawText("Generated by ZAnalytics from the selected endpoint template and report configuration. Validate endpoint paths, RBAC, and data semantics against your tenant before operational or executive use.", at: &y, attributes: bodyAttributes, maxHeight: 46)

        let cardWidth = (contentWidth - 24) / 3
        for (index, card) in result.summaryCards.prefix(6).enumerated() {
            if index == 3 { y -= 86 }
            let col = index % 3
            let rowY = y - 76
            let rect = CGRect(x: margin + CGFloat(col) * (cardWidth + 12), y: rowY, width: cardWidth, height: 72)
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
            NSString(string: card.title).draw(with: rect.insetBy(dx: 10, dy: 8), options: [.usesLineFragmentOrigin], attributes: captionAttributes)
            NSString(string: card.value).draw(with: CGRect(x: rect.minX + 10, y: rect.minY + 26, width: rect.width - 20, height: 26), options: [.usesLineFragmentOrigin], attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.labelColor])
            NSString(string: card.detail).draw(with: CGRect(x: rect.minX + 10, y: rect.minY + 8, width: rect.width - 20, height: 18), options: [.usesLineFragmentOrigin], attributes: captionAttributes)
        }
        y -= result.summaryCards.count > 3 ? 180 : 94

        drawText("Rows preview", at: &y, attributes: headingAttributes, maxHeight: 24)
        let headers = Array(Set(result.rows.flatMap { $0.keys })).sorted()
        let shownHeaders = Array(headers.prefix(5))
        let rowHeight: CGFloat = 24
        let columnWidth = contentWidth / CGFloat(max(shownHeaders.count, 1))
        func drawTableRow(_ values: [String], y rowY: CGFloat, isHeader: Bool) {
            for (index, value) in values.enumerated() {
                let rect = CGRect(x: margin + CGFloat(index) * columnWidth, y: rowY, width: columnWidth, height: rowHeight)
                (isHeader ? NSColor(calibratedRed: 0.89, green: 0.92, blue: 0.96, alpha: 1) : NSColor.white).setFill()
                rect.fill()
                NSColor.separatorColor.setStroke()
                rect.frame()
                NSString(string: value).draw(with: rect.insetBy(dx: 6, dy: 6), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: isHeader ? captionAttributes.merging([.font: NSFont.systemFont(ofSize: 8.5, weight: .semibold)]) { $1 } : captionAttributes)
            }
        }
        if !shownHeaders.isEmpty {
            drawTableRow(shownHeaders, y: y - rowHeight, isHeader: true)
            y -= rowHeight
            for row in result.rows.prefix(12) {
                if y < margin + rowHeight {
                    endPage()
                    y = beginPage()
                }
                drawTableRow(shownHeaders.map { row[$0]?.description ?? "" }, y: y - rowHeight, isHeader: false)
                y -= rowHeight
            }
        } else {
            drawText("No tabular rows were returned.", at: &y, attributes: bodyAttributes, maxHeight: 30)
        }
        endPage()
        context.closePDF()
        try data.write(to: url, options: .atomic)
    }
}

enum PowerPointReportRenderer {
    static func write(_ result: ReportResult, template: ReportPresentationTemplate, to url: URL) throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("ZAnalytics-")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        func write(_ relativePath: String, _ content: String) throws {
            let fileURL = staging.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let slides = slideXML(for: result, template: template)
        try write("[Content_Types].xml", contentTypes(slideCount: slides.count))
        try write("_rels/.rels", rootRelationships)
        try write("docProps/app.xml", appProperties(slideCount: slides.count))
        try write("docProps/core.xml", coreProperties(title: result.reportName))
        try write("ppt/presentation.xml", presentation(slideCount: slides.count))
        try write("ppt/_rels/presentation.xml.rels", presentationRelationships(slideCount: slides.count))
        try write("ppt/theme/theme1.xml", theme)
        try write("ppt/slideMasters/slideMaster1.xml", slideMaster)
        try write("ppt/slideMasters/_rels/slideMaster1.xml.rels", slideMasterRelationships)
        try write("ppt/slideLayouts/slideLayout1.xml", slideLayout)
        try write("ppt/slideLayouts/_rels/slideLayout1.xml.rels", slideLayoutRelationships)
        for (index, xml) in slides.enumerated() {
            try write("ppt/slides/slide\(index + 1).xml", xml)
            try write("ppt/slides/_rels/slide\(index + 1).xml.rels", slideRelationships)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = staging
        process.arguments = ["-qr", url.path, "."]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ExportError.renderingFailed("Could not package PowerPoint file.")
        }
    }

    private static func slideXML(for result: ReportResult, template: ReportPresentationTemplate) -> [String] {
        let title = result.reportName.xmlEscaped
        let subtitle = "\(template.label) • \(result.dateRangeDescription)".xmlEscaped
        let summary = "Generated \(result.generatedAt.formatted(date: .abbreviated, time: .shortened)) • Request ID: \(result.requestID)".xmlEscaped
        var slides = [titleSlide(title: title, subtitle: subtitle, body: summary)]

        let cards = result.summaryCards.prefix(6).enumerated().map { index, card in
            bullet("\(card.title): \(card.value) — \(card.detail)", level: index > 2 ? 1 : 0)
        }.joined()
        slides.append(contentSlide(title: "Key metrics", body: cards.isEmpty ? bullet("No summary metrics were returned.") : cards))

        let headers = Array(Set(result.rows.flatMap { $0.keys })).sorted().prefix(4)
        let rowBullets = result.rows.prefix(8).enumerated().map { index, row in
            let values = headers.map { "\($0): \(row[$0]?.description ?? "")" }.joined(separator: " | ")
            return bullet("Row \(index + 1): \(values)")
        }.joined()
        slides.append(contentSlide(title: "Rows preview", body: rowBullets.isEmpty ? bullet("No tabular rows were returned.") : rowBullets))
        return slides
    }

    private static func titleSlide(title: String, subtitle: String, body: String) -> String {
        slide(titleRuns: textBox(title, x: 685800, y: 914400, cx: 7772400, cy: 750000, fontSize: 3600, bold: true), bodyRuns: textBox("\(subtitle)\n\(body)", x: 685800, y: 1800000, cx: 7772400, cy: 1100000, fontSize: 1700, bold: false))
    }

    private static func contentSlide(title: String, body: String) -> String {
        slide(titleRuns: textBox(title.xmlEscaped, x: 457200, y: 320000, cx: 8229600, cy: 520000, fontSize: 3000, bold: true), bodyRuns: "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Content\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"685800\" y=\"1040000\"/><a:ext cx=\"7772400\" cy=\"4000000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr wrap=\"square\"/><a:lstStyle/>\(body)</p:txBody></p:sp>")
    }

    private static func slide(titleRuns: String, bodyRuns: String) -> String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="F7F9FC"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\(titleRuns)\(bodyRuns)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
    """ }

    private static func textBox(_ text: String, x: Int, y: Int, cx: Int, cy: Int, fontSize: Int, bold: Bool) -> String {
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            "<a:p><a:r><a:rPr lang=\"en-US\" sz=\"\(fontSize)\"\(bold ? " b=\"1\"" : "")><a:solidFill><a:srgbClr val=\"17202A\"/></a:solidFill></a:rPr><a:t>\(String(line).xmlEscaped)</a:t></a:r><a:endParaRPr lang=\"en-US\" sz=\"\(fontSize)\"/></a:p>"
        }.joined()
        return "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Text\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"\(x)\" y=\"\(y)\"/><a:ext cx=\"\(cx)\" cy=\"\(cy)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr wrap=\"square\"/><a:lstStyle/>\(paragraphs)</p:txBody></p:sp>"
    }

    private static func bullet(_ text: String, level: Int = 0) -> String {
        "<a:p><a:pPr lvl=\"\(level)\"><a:buChar char=\"•\"/></a:pPr><a:r><a:rPr lang=\"en-US\" sz=\"1500\"><a:solidFill><a:srgbClr val=\"263442\"/></a:solidFill></a:rPr><a:t>\(text.xmlEscaped)</a:t></a:r></a:p>"
    }

    private static func contentTypes(slideCount: Int) -> String {
        let slideOverrides = (1...slideCount).map { "<Override PartName=\"/ppt/slides/slide\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\(slideOverrides)</Types>
        """
    }

    private static func presentation(slideCount: Int) -> String {
        let ids = (1...slideCount).map { "<p:sldId id=\"\(255 + $0)\" r:id=\"rId\($0)\"/>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rIdMaster\"/></p:sldMasterIdLst><p:sldIdLst>\(ids)</p:sldIdLst><p:sldSz cx=\"9144000\" cy=\"5143500\" type=\"screen16x9\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/></p:presentation>"
    }

    private static func presentationRelationships(slideCount: Int) -> String {
        let slides = (1...slideCount).map { "<Relationship Id=\"rId\($0)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\($0).xml\"/>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(slides)<Relationship Id=\"rIdMaster\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/><Relationship Id=\"rIdTheme\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/></Relationships>"
    }

    private static let rootRelationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/></Relationships>"
    private static let slideRelationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/></Relationships>"
    private static let slideMasterRelationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"../theme/theme1.xml\"/></Relationships>"
    private static let slideLayoutRelationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/></Relationships>"
    private static let slideMaster = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><p:sldMaster xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/><p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>"
    private static let slideLayout = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><p:sldLayout xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" type=\"blank\" preserve=\"1\"><p:cSld name=\"Blank\"><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"
    private static let theme = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"ZAnalytics\"><a:themeElements><a:clrScheme name=\"ZAnalytics\"><a:dk1><a:srgbClr val=\"17202A\"/></a:dk1><a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1><a:dk2><a:srgbClr val=\"12324A\"/></a:dk2><a:lt2><a:srgbClr val=\"F4F6F8\"/></a:lt2><a:accent1><a:srgbClr val=\"1F6F78\"/></a:accent1><a:accent2><a:srgbClr val=\"2364AA\"/></a:accent2><a:accent3><a:srgbClr val=\"1F8F7A\"/></a:accent3><a:accent4><a:srgbClr val=\"EAD28A\"/></a:accent4><a:accent5><a:srgbClr val=\"5C6675\"/></a:accent5><a:accent6><a:srgbClr val=\"DDE5EF\"/></a:accent6><a:hlink><a:srgbClr val=\"2364AA\"/></a:hlink><a:folHlink><a:srgbClr val=\"1F6F78\"/></a:folHlink></a:clrScheme><a:fontScheme name=\"ZAnalytics\"><a:majorFont><a:latin typeface=\"Aptos Display\"/></a:majorFont><a:minorFont><a:latin typeface=\"Aptos\"/></a:minorFont></a:fontScheme><a:fmtScheme name=\"ZAnalytics\"><a:fillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w=\"6350\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>"
    private static func appProperties(slideCount: Int) -> String { "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\"><Application>ZAnalytics</Application><PresentationFormat>On-screen Show (16:9)</PresentationFormat><Slides>\(slideCount)</Slides></Properties>" }
    private static func coreProperties(title: String) -> String { "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><dc:title>\(title.xmlEscaped)</dc:title><dc:creator>ZAnalytics</dc:creator><cp:lastModifiedBy>ZAnalytics</cp:lastModifiedBy></cp:coreProperties>" }
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

    var xmlEscaped: String {
        htmlEscaped.replacingOccurrences(of: "'", with: "&apos;")
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
