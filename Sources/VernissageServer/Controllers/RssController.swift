//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import Fluent
import ActivityPubKit

extension RssController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rssGroup = routes
            .grouped("rss")
        
        // Support for RSS feed: https://example.com/rss/users/@johndoe
        rssGroup
            .grouped(EventHandlerMiddleware(.rssUser))
            .grouped(CacheControlMiddleware(.noStore))
            .get("users", ":name", use: user)
    }
}

/// Controller for exposing RSS feeds.
///
/// This controller hosts endpoints for different RSS feeds.
///
/// > Important: Base controller URL: `/rss`.
struct RssController {
    let activityPubActorsController = ActivityPubActorsController()
        
    /// Returns user's RSS feed with latest statuses.
    ///
    /// > Important: Endpoint URL: `/:name/rss`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/@johndoe/rss" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>John Doe</title>
    ///        <description>Public posts from @johndoe@example.com</description>
    ///        <link>http://example.com/@johndoe</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <webfeeds:icon>https://example.com/assets/icons/icon-512x512.png</webfeeds:icon>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <image>
    ///            <url>https://example.com/vernissage-test/0fc159c5d78d496f9bdb3195b8e651cc.png</url>
    ///            <title>John Doe</title>
    ///            <link>http://example.com/@johndoe</link>
    ///        </image>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about user information.
    @Sendable
    func user(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let rssService = request.application.services.rssService
        let clearedUserName = userName.deletingPrefix("@")
        let userFromDb = try await usersService.get(userName: clearedUserName, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let xmlDocument = try await rssService.feed(for: user, on: request.executionContext)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/rss+xml; charset=utf-8")
        
        return try await xmlDocument.encodeResponse(status: .ok, headers: headers, for: request)
    }
}
