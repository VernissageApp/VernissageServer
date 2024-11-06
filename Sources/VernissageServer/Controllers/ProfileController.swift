//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension ProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // Support for: https://example.com/@johndoe.
        routes
            .grouped(UserAuthenticator())
            .grouped(EventHandlerMiddleware(.usersRead))
            .get(":name", use: read)
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
    /// > Important: Endpoint URL: `/api/v1/actors`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe" \
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
}
