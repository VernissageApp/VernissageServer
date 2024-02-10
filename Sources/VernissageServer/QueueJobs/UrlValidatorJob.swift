//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp
import RegexBuilder

/// Background job for user's fields validation.
struct UrlValidatorJob: AsyncJob {
    typealias Payload = FlexiField
    
    func dequeue(_ context: QueueContext, _ payload: FlexiField) async throws {
        context.logger.info("UrlValidatorJob dequeued job. FlexiField (id: '\(payload.stringId() ?? "<unknown>")', value: '\(payload.value ?? "<unknown>")').")

        guard let flexiFieldFromDatabase = try await FlexiField.query(on: context.application.db)
            .with(\.$user)
            .filter(\.$id == payload.requireID()).first() else {
            return
        }
        
        guard let flexiFieldValue =  payload.value else {
            return
        }
        
        guard flexiFieldValue.contains("https://") else {
            return
        }

        // Download HTML from external server.
        let uri = URI(string: flexiFieldValue)
        var response = try await context.application.client.get(uri)

        // Read response as string.
        guard let readableBytes = response.body?.readableBytes,
              let string = response.body?.readString(length: readableBytes) else {
            return
        }
        
        let appplicationSettings = context.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let profileUrl = "\(baseAddress)/@\(flexiFieldFromDatabase.user.userName)".lowercased()
        let htmlAnchors = try Regex("(?<Link><a.*?(?<Href>href=[\"'](?<HrefValue>.*?)[\"']).*?>(?<Content>.*?)</a>)")

        let matches = string.matches(of: htmlAnchors)
        
        for match in matches {
            guard let hrefValue = match["HrefValue"]?.value else {
                continue
            }
            
            guard let link = match["Link"]?.value else {
                continue
            }

            let hrefValueString = String(describing: hrefValue)
            let linkString = String(describing: link)
            
            guard hrefValueString.lowercased() == profileUrl else {
                continue
            }
            
            if self.containsRelMe(link: linkString) {
                context.logger.info("Page '\(flexiFieldValue)' contains rel=\"me\" to: '\(profileUrl)' profile.")
                
                flexiFieldFromDatabase.isVerified = true
                try await flexiFieldFromDatabase.save(on: context.application.db)
            }
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: FlexiField) async throws {
        context.logger.error("UrlValidatorJob error: \(error.localizedDescription). FlexiField (id: '\(payload.stringId() ?? "<unknown>")', value: '\(payload.value ?? "<unknown>")').")
    }
    
    private func containsRelMe(link: String) -> Bool {
        return link.contains("\"me ") ||
            link.contains("'me ") ||
            link.contains(" me ") ||
            link.contains(" me\"") ||
            link.contains(" me'")
    }
}
