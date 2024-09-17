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
            context.logger.notice("Cannot find flexi field id '\(payload.stringId() ?? "<unknown>")' in the database.")
            return
        }
        
        guard let flexiFieldUrl = self.getUrlFrom(flexiField: flexiFieldFromDatabase) else {
            context.logger.notice("Cannot find url in the flexi field value: '\(flexiFieldFromDatabase.value ?? "<unknown>")'.")
            return
        }
        
        guard flexiFieldUrl.contains("https://") else {
            context.logger.notice("Field value url '\(flexiFieldUrl)' doesn't contain 'https://' string.")
            return
        }
        
        // Prepare user link to Vernissage profile.
        guard let profileUrl = flexiFieldFromDatabase.user.url?.lowercased() else {
            context.logger.notice("Cannot find user's profile url in Users table for user: '\(flexiFieldFromDatabase.user.userName)'.")
            return
        }

        // Download HTML from external server.
        let uri = URI(string: flexiFieldUrl)
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
                context.logger.info("Page '\(flexiFieldUrl)' contains rel=\"me\" to: '\(profileUrl)' profile.")
                
                flexiFieldFromDatabase.isVerified = true
                try await flexiFieldFromDatabase.save(on: context.application.db)
                
                break
            }
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: FlexiField) async throws {
        context.logger.error("UrlValidatorJob error: \(error.localizedDescription). FlexiField (id: '\(payload.stringId() ?? "<unknown>")', value: '\(payload.value ?? "<unknown>")').")
    }
    
    private func getUrlFrom(flexiField: FlexiField) -> String? {
        guard let flexiFieldValue = flexiField.value else {
            return nil
        }
        
        // For local users we don't have HTML in the flexi values.
        if flexiField.user.isLocal {
            return flexiFieldValue
        }
        
        // Remote user's in flexi field values can contain HTML with anchor element.
        let hrefUrlRegex = #/href="(?<url>[^"]*)"/#
        
        let hrefUrlMatch = flexiFieldValue.firstMatch(of: hrefUrlRegex)
        guard let url = hrefUrlMatch?.url else {
            return flexiFieldValue
        }
        
        return String(url)
    }
}
