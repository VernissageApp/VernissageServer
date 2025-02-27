//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import Fluent
import ActivityPubKit

extension ProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // Support for: https://example.com/@johndoe
        routes
            .grouped(UserAuthenticator())
            .grouped(EventHandlerMiddleware(.usersRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", use: read)
        
        // Support for RSS feed: https://example.com/@johndoe/rss
        routes
            .grouped(UserAuthenticator())
            .grouped(EventHandlerMiddleware(.usersRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", "rss", use: rss)
    }
}

/// Controller for exposing user profile.
///
/// The controller is created specificaly for supporting downloading
/// user accounts during search from other fediverse platforms.
///
/// > Important: Base controller URL: `/:username`.
struct ProfileController {
    let activityPubActorsController = ActivityPubActorsController()
    
    /// Returns user ActivityPub profile.
    ///
    /// Endpoint for download Activity Pub actor's data. One of the property is public key which should be used to validate requests
    /// done (and signed by private key) by the user in all Activity Pub protocol methods.
    ///
    /// > Important: Endpoint URL: `/:name`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/@johndoe" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "@context": [
    ///         "https://w3id.org/security/v1",
    ///         "https://www.w3.org/ns/activitystreams"
    ///     ],
    ///     "attachment": [
    ///         {
    ///             "name": "MASTODON",
    ///             "type": "PropertyValue",
    ///             "value": "https://mastodon.social/@johndoe"
    ///         },
    ///         {
    ///             "name": "GITHUB",
    ///             "type": "PropertyValue",
    ///             "value": "https://github.com/johndoe"
    ///         }
    ///     ],
    ///     "endpoints": {
    ///         "sharedInbox": "https://example.com/shared/inbox"
    ///     },
    ///     "followers": "https://example.com/actors/johndoe/followers",
    ///     "following": "https://example.com/actors/johndoe/following",
    ///     "icon": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    ///     },
    ///     "id": "https://example.com/actors/johndoe",
    ///     "image": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    ///     },
    ///     "inbox": "https://example.com/actors/johndoe/inbox",
    ///     "manuallyApprovesFollowers": false,
    ///     "name": "John Doe",
    ///     "outbox": "https://example.com/actors/johndoe/outbox",
    ///     "preferredUsername": "johndoe",
    ///     "publicKey": {
    ///         "id": "https://example.com/actors/johndoe#main-key",
    ///         "owner": "https://example.com/actors/johndoe",
    ///         "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nM0Q....AB\n-----END PUBLIC KEY-----"
    ///     },
    ///     "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    ///     "tag": [
    ///         {
    ///             "href": "https://example.com/tags/Apple",
    ///             "name": "Apple",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/dotNET",
    ///             "name": "dotNET",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/iOS",
    ///             "name": "iOS",
    ///             "type": "Hashtag"
    ///         }
    ///     ],
    ///     "type": "Person",
    ///     "url": "https://example.com/@johndoe",
    ///     "alsoKnownAs": [
    ///         "https://test.social/users/marcin"
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about user information.
    @Sendable
    func read(request: Request) async throws -> Response {
        return try await activityPubActorsController.read(request: request)
    }
    
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
    func rss(request: Request) async throws -> Response {
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
        
        return try await xmlDocument.xmlString.encodeResponse(status: .ok, headers: headers, for: request)
    }
}
