//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp
import RegexBuilder
import SwiftSoup

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
        
        guard let flexiFieldValue = payload.value else {
            return
        }
        
        guard flexiFieldValue.contains("https://") else {
            return
        }
        
        // Prepare user link to Vernissage profile.
        let appplicationSettings = context.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let profileUrl = "\(baseAddress)/@\(flexiFieldFromDatabase.user.userName)".lowercased()

        // Download HTML from external server.
        let uri = URI(string: flexiFieldValue)
        var response = try await context.application.client.get(uri)

        // Read response as string.
        guard let readableBytes = response.body?.readableBytes,
              let string = response.body?.readString(length: readableBytes) else {
            return
        }
        
        // Parse string as a HTML document.
        guard let html = try? SwiftSoup.parse(string) else {
            context.logger.notice("Cannot parse HTML from: '\(uri)'.")
            return
        }
        
        // Find all anchors with rel="me".
        guard let anchors = try? html.select("a[rel*=me],link[rel*=me]") else {
            context.logger.notice("Cannot find any element with rel=\"me\" in HTML from: '\(uri)'.")
            return
        }

        // Iterate throught anchors and check if we have one which point to Vernissage profile.
        for anchor in anchors.array() {
            let link = try anchor.attr("href")
            
            if link.lowercased() == profileUrl {
                context.logger.info("Page '\(flexiFieldValue)' contains rel=\"me\" to: '\(profileUrl)' profile.")
                
                flexiFieldFromDatabase.isVerified = true
                try await flexiFieldFromDatabase.save(on: context.application.db)
                
                break
            }
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: FlexiField) async throws {
        context.logger.error("UrlValidatorJob error: \(error.localizedDescription). FlexiField (id: '\(payload.stringId() ?? "<unknown>")', value: '\(payload.value ?? "<unknown>")').")
    }
}
