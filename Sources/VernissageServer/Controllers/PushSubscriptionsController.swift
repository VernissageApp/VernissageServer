//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension PushSubscriptionsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("push-subscriptions")

    func boot(routes: RoutesBuilder) throws {
        let domainsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(PushSubscriptionsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        domainsGroup
            .grouped(EventHandlerMiddleware(.pushSubscriptionsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.pushSubscriptionsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.pushSubscriptionsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        domainsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.pushSubscriptionsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Controls basic operations for web push subscriptions.
///
/// With this controller, user can subscribe for retrieving WebPush notifications (in supported browsers).
///
/// > Important: Base controller URL: `/api/v1/push-subscriptions`.
struct PushSubscriptionsController {

    /// List of web push subscriptions.
    ///
    /// The endpoint returns a list of all push subscriptions added to the system by the user.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/push-subscriptions`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/push-subscriptions" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "id": "7267938074834522113",
    ///             "endpoint": "http://server.push/23rwef34g35gdfdsf",
    ///             "userAgentPublicKey": "qrfwdvhs78fvyas8dfgvb8asdfgb0av",
    ///             "auth": "sdva9srhv0asdf7hv80a",
    ///             "webPushNotificationsEnabled": true,
    ///             "webPushMentionEnabled": true,
    ///             "webPushStatusEnabled": true,
    ///             "webPushReblogEnabled": true,
    ///             "webPushFollowEnabled": true,
    ///             "webPushFollowRequestEnabled": true,
    ///             "webPushFavouriteEnabled": true,
    ///             "webPushUpdateEnabled": true,
    ///             "webPushAdminSignUpEnabled": true,
    ///             "webPushAdminReportEnabled": true,
    ///             "webPushNewCommentEnabled": true,
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "updatedAt": "2024-02-09T05:12:23.479Z"
    ///         },
    ///         {
    ///             "id": "7267938074834522113",
    ///             "endpoint": "http://goog.push/sdvasdv89hs9dfv",
    ///             "userAgentPublicKey": "asdadvsvoifbv0iodfb",
    ///             "auth": "sdv0er89hv0ev",
    ///             "webPushNotificationsEnabled": true,
    ///             "webPushMentionEnabled": true,
    ///             "webPushStatusEnabled": false,
    ///             "webPushReblogEnabled": true,
    ///             "webPushFollowEnabled": false,
    ///             "webPushFollowRequestEnabled": true,
    ///             "webPushFavouriteEnabled": false,
    ///             "webPushUpdateEnabled": true,
    ///             "webPushAdminSignUpEnabled": false,
    ///             "webPushAdminReportEnabled": true,
    ///             "webPushNewCommentEnabled": true,
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "updatedAt": "2024-02-09T05:12:23.479Z"
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 2,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of push subscriptions.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<PushSubscriptionDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let pushSubscriptionsFromDatabase = try await PushSubscription.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .sort(\.$endpoint, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let pushSubscriptionsDto = pushSubscriptionsFromDatabase.items.map { pushSubscription in
            PushSubscriptionDto(from: pushSubscription)
        }

        return PaginableResultDto(
            data: pushSubscriptionsDto,
            page: pushSubscriptionsFromDatabase.metadata.page,
            size: pushSubscriptionsFromDatabase.metadata.per,
            total: pushSubscriptionsFromDatabase.metadata.total
        )
    }
    
    /// Create new push subscription.
    ///
    /// The endpoint can be used for creating new push subscription by the user.
    /// For now user can have only one push subscription (thus only one device will be informed about notification).
    ///
    /// > Important: Endpoint URL: `/api/v1/push-subscriptions`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/push-subscriptions" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "endpoint": "http://server.push/23rwef34g35gdfdsf",
    ///     "userAgentPublicKey": "qrfwdvhs78fvyas8dfgvb8asdfgb0av",
    ///     "auth": "sdva9srhv0asdf7hv80a",
    ///     "webPushNotificationsEnabled": true,
    ///     "webPushMentionEnabled": true,
    ///     "webPushStatusEnabled": true,
    ///     "webPushReblogEnabled": true,
    ///     "webPushFollowEnabled": true,
    ///     "webPushFollowRequestEnabled": true,
    ///     "webPushFavouriteEnabled": true,
    ///     "webPushUpdateEnabled": true,
    ///     "webPushAdminSignUpEnabled": true,
    ///     "webPushAdminReportEnabled": true,
    ///     "webPushNewCommentEnabled": true,
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "endpoint": "http://server.push/23rwef34g35gdfdsf",
    ///     "userAgentPublicKey": "qrfwdvhs78fvyas8dfgvb8asdfgb0av",
    ///     "auth": "sdva9srhv0asdf7hv80a",
    ///     "webPushNotificationsEnabled": true,
    ///     "webPushMentionEnabled": true,
    ///     "webPushStatusEnabled": true,
    ///     "webPushReblogEnabled": true,
    ///     "webPushFollowEnabled": true,
    ///     "webPushFollowRequestEnabled": true,
    ///     "webPushFavouriteEnabled": true,
    ///     "webPushUpdateEnabled": true,
    ///     "webPushAdminSignUpEnabled": true,
    ///     "webPushAdminReportEnabled": true,
    ///     "webPushNewCommentEnabled": true,
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let pushSubscriptionDto = try request.content.decode(PushSubscriptionDto.self)
        try PushSubscriptionDto.validate(content: request)
        
        let id = request.application.services.snowflakeService.generate()
        let pushSubscription = PushSubscription(id: id,
                                                userId: authorizationPayloadId,
                                                endpoint: pushSubscriptionDto.endpoint,
                                                userAgentPublicKey: pushSubscriptionDto.userAgentPublicKey,
                                                auth: pushSubscriptionDto.auth,
                                                webPushNotificationsEnabled: pushSubscriptionDto.webPushNotificationsEnabled,
                                                webPushMentionEnabled: pushSubscriptionDto.webPushMentionEnabled,
                                                webPushStatusEnabled: pushSubscriptionDto.webPushStatusEnabled,
                                                webPushReblogEnabled: pushSubscriptionDto.webPushReblogEnabled,
                                                webPushFollowEnabled: pushSubscriptionDto.webPushFollowEnabled,
                                                webPushFollowRequestEnabled: pushSubscriptionDto.webPushFollowRequestEnabled,
                                                webPushFavouriteEnabled: pushSubscriptionDto.webPushFavouriteEnabled,
                                                webPushUpdateEnabled: pushSubscriptionDto.webPushUpdateEnabled,
                                                webPushAdminSignUpEnabled: pushSubscriptionDto.webPushAdminSignUpEnabled,
                                                webPushAdminReportEnabled: pushSubscriptionDto.webPushAdminReportEnabled,
                                                webPushNewCommentEnabled: pushSubscriptionDto.webPushNewCommentEnabled
        )
        
        try await request.db.transaction { transaction in

            // Delete old push subscriptions with same endpoint (other user's in the same browser).
            try await PushSubscription.query(on: transaction)
                .filter(\.$endpoint == pushSubscriptionDto.endpoint)
                .delete()
            
            // Save new subscription.
            try await pushSubscription.save(on: transaction)
        }
        
        return try await createNewPushSubscriptionResponse(on: request, pushSubscription: pushSubscription)
    }
    
    /// Update user push subscription in the database.
    ///
    /// The endpoint can be used for updating existing user's push subscriptions.
    ///
    /// > Important: Endpoint URL: `/api/v1/push-subscriptions/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/push-subscriptions/:id" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "endpoint": "http://server.push/23rwef34g35gdfdsf",
    ///     "userAgentPublicKey": "qrfwdvhs78fvyas8dfgvb8asdfgb0av",
    ///     "auth": "sdva9srhv0asdf7hv80a",
    ///     "webPushNotificationsEnabled": true,
    ///     "webPushMentionEnabled": true,
    ///     "webPushStatusEnabled": true,
    ///     "webPushReblogEnabled": true,
    ///     "webPushFollowEnabled": true,
    ///     "webPushFollowRequestEnabled": true,
    ///     "webPushFavouriteEnabled": true,
    ///     "webPushUpdateEnabled": true,
    ///     "webPushAdminSignUpEnabled": true,
    ///     "webPushAdminReportEnabled": true,
    ///     "webPushNewCommentEnabled": true,
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7267938074834522113",
    ///     "endpoint": "http://server.push/23rwef34g35gdfdsf",
    ///     "userAgentPublicKey": "qrfwdvhs78fvyas8dfgvb8asdfgb0av",
    ///     "auth": "sdva9srhv0asdf7hv80a",
    ///     "webPushNotificationsEnabled": true,
    ///     "webPushMentionEnabled": true,
    ///     "webPushStatusEnabled": true,
    ///     "webPushReblogEnabled": true,
    ///     "webPushFollowEnabled": true,
    ///     "webPushFollowRequestEnabled": true,
    ///     "webPushFavouriteEnabled": true,
    ///     "webPushUpdateEnabled": true,
    ///     "webPushAdminSignUpEnabled": true,
    ///     "webPushAdminReportEnabled": true,
    ///     "webPushNewCommentEnabled": true,
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "updatedAt": "2024-02-09T05:12:23.479Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    @Sendable
    func update(request: Request) async throws -> PushSubscriptionDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let pushSubscriptionDto = try request.content.decode(PushSubscriptionDto.self)
        try PushSubscriptionDto.validate(content: request)
        
        guard let pushSubscriptionIdString = request.parameters.get("id", as: String.self) else {
            throw PushSubscriptionError.incorrectPushSubscriptionId
        }
        
        guard let pushSubscriptionId = pushSubscriptionIdString.toId() else {
            throw PushSubscriptionError.incorrectPushSubscriptionId
        }
        
        guard let pushSubscription = try await PushSubscription.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$id == pushSubscriptionId)
            .first() else {
            throw EntityNotFoundError.pushSubscriptionNotFound
        }
        
        pushSubscription.endpoint = pushSubscriptionDto.endpoint
        pushSubscription.userAgentPublicKey = pushSubscriptionDto.userAgentPublicKey
        pushSubscription.auth = pushSubscriptionDto.auth
        pushSubscription.webPushNotificationsEnabled = pushSubscriptionDto.webPushNotificationsEnabled
        pushSubscription.webPushMentionEnabled = pushSubscriptionDto.webPushMentionEnabled
        pushSubscription.webPushStatusEnabled = pushSubscriptionDto.webPushStatusEnabled
        pushSubscription.webPushReblogEnabled = pushSubscriptionDto.webPushReblogEnabled
        pushSubscription.webPushFollowEnabled = pushSubscriptionDto.webPushFollowEnabled
        pushSubscription.webPushFollowRequestEnabled = pushSubscriptionDto.webPushFollowRequestEnabled
        pushSubscription.webPushFavouriteEnabled = pushSubscriptionDto.webPushFavouriteEnabled
        pushSubscription.webPushUpdateEnabled = pushSubscriptionDto.webPushUpdateEnabled
        pushSubscription.webPushAdminSignUpEnabled = pushSubscriptionDto.webPushAdminSignUpEnabled
        pushSubscription.webPushAdminReportEnabled = pushSubscriptionDto.webPushAdminReportEnabled
        pushSubscription.webPushNewCommentEnabled = pushSubscriptionDto.webPushNewCommentEnabled

        try await pushSubscription.save(on: request.db)
        return PushSubscriptionDto(from: pushSubscription)
    }
    
    /// Delete push subscription from the database.
    ///
    /// The endpoint can be used for deleting existing user's push subscription.
    ///
    /// > Important: Endpoint URL: `/api/v1/push-subscriptions/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/push-subscriptions/:id" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let pushSubscriptionIdString = request.parameters.get("id", as: String.self) else {
            throw PushSubscriptionError.incorrectPushSubscriptionId
        }
        
        guard let pushSubscriptionId = pushSubscriptionIdString.toId() else {
            throw PushSubscriptionError.incorrectPushSubscriptionId
        }
        
        guard let pushSubscription = try await PushSubscription.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$id == pushSubscriptionId)
            .first() else {
            throw EntityNotFoundError.pushSubscriptionNotFound
        }
        
        try await pushSubscription.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewPushSubscriptionResponse(on request: Request, pushSubscription: PushSubscription) async throws -> Response {
        let pushSubscriptionDto = PushSubscriptionDto(from: pushSubscription)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(PushSubscriptionsController.uri)/@\(pushSubscription.stringId() ?? "")")
        
        return try await pushSubscriptionDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
