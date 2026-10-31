//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

final class WebfingerXMLParser: NSObject, XMLParserDelegate {
    private let namespace = "http://docs.oasis-open.org/ns/xri/xrd-1.0"
    private var depth = 0
    private var text = ""
    private var isXRD = false
    private var subject = ""
    private var aliases: [String] = []
    private var links: [WebfingerLinkDto] = []

    static func parse(data: Data) throws -> WebfingerDto {
        let delegate = WebfingerXMLParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate

        guard parser.parse(), delegate.isXRD, delegate.subject.isEmpty == false else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid WebFinger XRD document.", underlyingError: parser.parserError))
        }

        return WebfingerDto(subject: delegate.subject, aliases: delegate.aliases, links: delegate.links)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        depth += 1
        if depth == 1 {
            isXRD = elementName == "XRD" && namespaceURI == namespace
        }
        guard isXRD, depth == 2, namespaceURI == namespace else { return }
        text = ""
        if elementName == "Link", let rel = attributeDict["rel"] {
            links.append(WebfingerLinkDto(rel: rel, type: attributeDict["type"], href: attributeDict["href"], template: attributeDict["template"]))
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if depth == 2 { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if isXRD, depth == 2, namespaceURI == namespace {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if elementName == "Subject" { subject = value }
            if elementName == "Alias" { aliases.append(value) }
        }
        depth -= 1
    }
}
