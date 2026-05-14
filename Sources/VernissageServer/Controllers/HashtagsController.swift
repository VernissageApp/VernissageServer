//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension HashtagsController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("hashtags")

    func boot(routes: RoutesBuilder) throws {
        let hashtagsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(HashtagsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        hashtagsGroup
            .grouped(EventHandlerMiddleware(.hashtagsFollowed))
            .grouped(CacheControlMiddleware(.noStore))
            .get("followed", use: followed)

        hashtagsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.hashtagsFollow))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":name", "follow", use: follow)

        hashtagsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.hashtagsUnfollow))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":name", "unfollow", use: unfollow)
    }
}

/// Operations on hashtags.
///
/// The controller allows signed-in users to operate on hashtags.
/// Currently it supports managing followed hashtags.
///
/// > Important: Base controller URL: `/api/v1/hashtags`.
struct HashtagsController {

    /// Get list of followed hashtags for the signed-in user.
    ///
    /// The endpoint returns hashtags currently followed by the authenticated user.
    ///
    /// > Important: Endpoint URL: `/api/v1/hashtags/followed`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/hashtags/followed" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [
    ///     {
    ///         "name": "street",
    ///         "url": "https://example.com/tags/street"
    ///     },
    ///     {
    ///         "name": "blackandwhite",
    ///         "url": "https://example.com/tags/blackandwhite"
    ///     }
    /// ]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Array of followed hashtags.
    @Sendable
    func followed(request: Request) async throws -> [HashtagDto] {
        let authorizationPayloadId = try request.requireUserId()
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let followedHashtags = try await UserFollowedHashtag.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .sort(\.$createdAt, .descending)
            .all()

        return followedHashtags.map {
            HashtagDto(url: "\(baseAddress)/tags/\($0.hashtag)", name: $0.hashtag)
        }
    }

    /// Follow hashtag by the signed-in user.
    ///
    /// The endpoint adds hashtag to current user's followed hashtags list.
    /// If the hashtag already exists for this user, operation is idempotent.
    ///
    /// > Important: Endpoint URL: `/api/v1/hashtags/:name/follow`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/hashtags/street/follow" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "name": "street",
    ///     "url": "https://example.com/tags/street"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Followed hashtag.
    ///
    /// - Throws: `HashtagError.hashtagNameIsRequired` if hashtag is empty.
    /// - Throws: `HashtagError.hashtagNameIsTooLong` if hashtag is longer than 100 characters.
    @Sendable
    func follow(request: Request) async throws -> HashtagDto {
        let authorizationPayloadId = try request.requireUserId()
        let hashtagsService = request.application.services.hashtagsService
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        guard let hashtagFromPath = request.parameters.get("name") else {
            throw HashtagError.hashtagNameIsRequired
        }

        let hashtag = hashtagsService.clear(hashtag: hashtagFromPath)
        guard hashtag.isEmpty == false else {
            throw HashtagError.hashtagNameIsRequired
        }

        guard hashtag.count <= 100 else {
            throw HashtagError.hashtagNameIsTooLong
        }

        let hashtagNormalized = hashtag.uppercased()

        if let followedHashtag = try await hashtagsService.getUserFollowedHashtag(for: authorizationPayloadId,
                                                                                   hashtagNormalized: hashtagNormalized,
                                                                                   on: request.db) {
            return HashtagDto(url: "\(baseAddress)/tags/\(followedHashtag.hashtag)", name: followedHashtag.hashtag)
        }

        let id = request.application.services.snowflakeService.generate()
        let userFollowedHashtag = UserFollowedHashtag(id: id, userId: authorizationPayloadId, hashtag: hashtag)
        try await userFollowedHashtag.save(on: request.db)

        return HashtagDto(url: "\(baseAddress)/tags/\(hashtag)", name: hashtag)
    }

    /// Unfollow hashtag by the signed-in user.
    ///
    /// The endpoint removes hashtag from current user's followed hashtags list.
    /// If hashtag does not exist for this user, operation is idempotent.
    ///
    /// > Important: Endpoint URL: `/api/v1/hashtags/:name/unfollow`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/hashtags/street/unfollow" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `HashtagError.hashtagNameIsRequired` if hashtag is empty.
    /// - Throws: `HashtagError.hashtagNameIsTooLong` if hashtag is longer than 100 characters.
    @Sendable
    func unfollow(request: Request) async throws -> HTTPStatus {
        let authorizationPayloadId = try request.requireUserId()
        let hashtagsService = request.application.services.hashtagsService

        guard let hashtagFromPath = request.parameters.get("name") else {
            throw HashtagError.hashtagNameIsRequired
        }

        let hashtag = hashtagsService.clear(hashtag: hashtagFromPath)
        guard hashtag.isEmpty == false else {
            throw HashtagError.hashtagNameIsRequired
        }

        guard hashtag.count <= 100 else {
            throw HashtagError.hashtagNameIsTooLong
        }

        let hashtagNormalized = hashtag.uppercased()

        if let followedHashtag = try await hashtagsService.getUserFollowedHashtag(for: authorizationPayloadId,
                                                                                   hashtagNormalized: hashtagNormalized,
                                                                                   on: request.db) {
            try await followedHashtag.delete(on: request.db)
        }

        return .ok
    }
}
