//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension DirectMessagesController: RouteCollection {
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("direct-messages")

    func boot(routes: RoutesBuilder) throws {
        let directMessagesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(DirectMessagesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(CacheControlMiddleware(.noStore))

        directMessagesGroup
            .grouped(EventHandlerMiddleware(.directMessagesList, storeRequest: false, storeResponse: false))
            .get(use: list)

        directMessagesGroup
            .grouped(EventHandlerMiddleware(.directMessagesUnreadCount, storeRequest: false, storeResponse: false))
            .get("unread-count", use: unreadCount)

        directMessagesGroup
            .grouped(EventHandlerMiddleware(.directMessagesRead, storeRequest: false, storeResponse: false))
            .get(":id", use: read)

        directMessagesGroup
            .grouped(EventHandlerMiddleware(.directMessagesStatuses, storeRequest: false, storeResponse: false))
            .get(":id", "statuses", use: statuses)

        directMessagesGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.directMessagesCreate, storeRequest: false, storeResponse: false))
            .post(use: create)

        directMessagesGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.directMessagesReply, storeRequest: false, storeResponse: false))
            .post(":id", "statuses", use: reply)

        directMessagesGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.directMessagesMarkRead, storeRequest: false, storeResponse: false))
            .post(":id", "read", use: markRead)

        directMessagesGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.directMessagesMute, storeRequest: false, storeResponse: false))
            .put(":id", "mute", use: mute)
    }
}

/// Controls the authenticated user's direct-message inbox.
///
/// All actions require authentication, mutations also validate cookie-based XSRF tokens.
/// Explicit recipients control access to each message. Inbox membership does not grant access to the entire history.
///
/// > Important: Base controller URL: `/api/v1/direct-messages`.
struct DirectMessagesController {
    /// Exposing the current user's direct conversations.
    ///
    /// Returns personalized inbox entries ordered by descending `lastActivityAt`, then descending inbox id.
    /// New incoming messages move their conversation to the top. Participants and the plain-text preview
    /// describe only messages accessible to this user. The preview contains at most 200 characters.
    /// `hasUnreadMessages` can be used to display an unread indicator next to a conversation.
    /// `lastReadAt` records the last read action for this user and is absent before any read action.
    /// Listing conversations does not mark messages as read. Muted conversations remain in this list.
    ///
    /// Optional query params:
    /// - `page` - page number, starting at 1 (default: 1)
    /// - `size` - number of entries per page, from 1 to 100 (default: 20)
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages?page=1&size=20" \
    /// -X GET \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "id": "7333853122610761729",
    ///             "participants": [
    ///                 {
    ///                     "id": "7267938074834522113",
    ///                     "type": "person",
    ///                     "url": "https://example.com/@alex",
    ///                     "isLocal": true,
    ///                     "userName": "alex",
    ///                     "account": "alex@example.com",
    ///                     "name": "Alex",
    ///                     "photosCount": 0,
    ///                     "statusesCount": 0,
    ///                     "followersCount": 0,
    ///                     "followingCount": 0,
    ///                     "includePublicPostsInSearchEngines": false,
    ///                     "includeProfilePageInSearchEngines": false,
    ///                     "activityPubProfile": "https://example.com/actors/alex",
    ///                     "isSupporterFlagEnabled": false
    ///                 },
    ///                 {
    ///                     "id": "7332804261530576897",
    ///                     "type": "person",
    ///                     "url": "https://example.com/@sophie",
    ///                     "isLocal": true,
    ///                     "userName": "sophie",
    ///                     "account": "sophie@example.com",
    ///                     "name": "Sophie",
    ///                     "photosCount": 0,
    ///                     "statusesCount": 0,
    ///                     "followersCount": 0,
    ///                     "followingCount": 0,
    ///                     "includePublicPostsInSearchEngines": false,
    ///                     "includeProfilePageInSearchEngines": false,
    ///                     "activityPubProfile": "https://example.com/actors/sophie",
    ///                     "isSupporterFlagEnabled": false
    ///                 }
    ///             ],
    ///             "lastStatusId": "7333853122610761730",
    ///             "summary": "Hello!",
    ///             "lastActivityAt": "2026-10-10T10:24:00.000Z",
    ///             "hasUnreadMessages": true,
    ///             "isMuted": false
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 20,
    ///     "total": 1
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 200 (OK) with a paginated collection of `DirectConversationDto`.
    /// - Throws: `DirectMessageError.invalidPagination` if page is not positive or size is outside the 1–100 range.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<DirectConversationDto> {
        let parameters = try pagination(request)

        return try await request.application.services.directMessagesService.list(
            userId: request.requireUserId(),
            page: parameters.page,
            size: parameters.size,
            on: request.executionContext)
    }

    /// Counting conversations with unread incoming messages.
    ///
    /// Counts conversations, rather than individual messages, including muted conversations.
    /// For example, two unread messages in the same conversation contribute one to `count`.
    /// Reading this counter does not mark any message as read.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/unread-count`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/unread-count" \
    /// -X GET \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "count": 2
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 200 (OK) with `DirectConversationsUnreadCountDto`.
    /// - Throws: `Abort` if the request is not authenticated.
    @Sendable
    func unreadCount(request: Request) async throws -> DirectConversationsUnreadCountDto {
        let directMessagesService = request.application.services.directMessagesService
        let count = try await directMessagesService.unreadCount(userId: request.requireUserId(), on: request.executionContext)

        return DirectConversationsUnreadCountDto(count: count)
    }

    /// Reading a personalized direct-conversation inbox entry.
    ///
    /// The `id` path parameter is a `DirectConversation` identifier encoded as a string.
    /// Returns participants, the latest accessible message preview, activity time and the current user's
    /// read and mute state. Inbox membership does not grant access to messages addressed to other users.
    /// This action does not mark the conversation as read.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/7333853122610761729" \
    /// -X GET \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333853122610761729",
    ///     "participants": [
    ///         {
    ///             "id": "7267938074834522113",
    ///             "type": "person",
    ///             "url": "https://example.com/@alex",
    ///             "isLocal": true,
    ///             "userName": "alex",
    ///             "account": "alex@example.com",
    ///             "name": "Alex",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/alex",
    ///             "isSupporterFlagEnabled": false
    ///         },
    ///         {
    ///             "id": "7332804261530576897",
    ///             "type": "person",
    ///             "url": "https://example.com/@sophie",
    ///             "isLocal": true,
    ///             "userName": "sophie",
    ///             "account": "sophie@example.com",
    ///             "name": "Sophie",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/sophie",
    ///             "isSupporterFlagEnabled": false
    ///         }
    ///     ],
    ///     "lastStatusId": "7333853122610761730",
    ///     "summary": "Hello!",
    ///     "lastActivityAt": "2026-10-10T10:24:00.000Z",
    ///     "hasUnreadMessages": true,
    ///     "isMuted": false
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 200 (OK) with `DirectConversationDto`.
    /// - Throws: `DirectMessageError.invalidId` if conversation id is incorrect.
    /// - Throws: `DirectMessageError.conversationNotFound` if the conversation is not found in the current user's inbox.
    @Sendable
    func read(request: Request) async throws -> DirectConversationDto {
        let directMessagesService = request.application.services.directMessagesService
        let conversation = try await directMessagesService.conversation(id: conversationId(request),
                                                                        userId: request.requireUserId(),
                                                                        on: request.executionContext)
        
        return conversation
    }

    /// Exposing accessible messages in a direct conversation.
    ///
    /// The `id` path parameter is a `DirectConversation` identifier encoded as a string.
    /// Messages are ordered newest first by their local status id. Each entry includes the underlying
    /// `StatusDto`, explicit recipients (`UserDto`) and the current recipient's `readAt` timestamp.
    /// `readAt` is omitted for unread incoming messages and for messages authored by the current user.
    /// The example shows a message already marked as read by its recipient.
    /// Only the author and explicit recipients can see a message. Messages addressed solely to other
    /// participants are omitted, including earlier messages sent before this user joined.
    /// Fetching this page does not mark any message as read.
    ///
    /// **Deleted-message entry (the `status` field is omitted):**
    ///
    /// Optional query params:
    /// - `page` - page number, starting at 1 (default: 1)
    /// - `size` - number of entries per page, from 1 to 100 (default: 20)
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/:id/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/7333853122610761729/statuses?page=1&size=20" \
    /// -X GET \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "id": "7333853122610761730",
    ///             "conversationId": "7333853122610761729",
    ///             "status": {
    ///                 "id": "7333853122610761730",
    ///                 "isLocal": true,
    ///                 "note": "Hello!",
    ///                 "noteHtml": "<p>Hello!</p>",
    ///                 "visibility": "mentioned",
    ///                 "sensitive": false,
    ///                 "commentsDisabled": false,
    ///                 "user": {
    ///                     "id": "7267938074834522113",
    ///                     "type": "person",
    ///                     "url": "https://example.com/@alex",
    ///                     "isLocal": true,
    ///                     "userName": "alex",
    ///                     "account": "alex@example.com",
    ///                     "name": "Alex",
    ///                     "photosCount": 0,
    ///                     "statusesCount": 0,
    ///                     "followersCount": 0,
    ///                     "followingCount": 0,
    ///                     "includePublicPostsInSearchEngines": false,
    ///                     "includeProfilePageInSearchEngines": false,
    ///                     "activityPubProfile": "https://example.com/actors/alex",
    ///                     "isSupporterFlagEnabled": false
    ///                 },
    ///                 "activityPubId": "https://example.com/actors/alex/statuses/7333853122610761730",
    ///                 "activityPubUrl": "https://example.com/@alex/7333853122610761730",
    ///                 "attachments": [],
    ///                 "tags": [],
    ///                 "repliesCount": 0,
    ///                 "reblogsCount": 0,
    ///                 "favouritesCount": 0,
    ///                 "favourited": false,
    ///                 "reblogged": false,
    ///                 "bookmarked": false,
    ///                 "featured": false,
    ///                 "publishedAt": "2026-10-10T10:24:00.000Z",
    ///                 "createdAt": "2026-10-10T10:24:00.000Z",
    ///                 "updatedAt": "2026-10-10T10:24:00.000Z"
    ///             },
    ///             "recipients": [
    ///                 {
    ///                     "id": "7332804261530576897",
    ///                     "type": "person",
    ///                     "url": "https://example.com/@sophie",
    ///                     "isLocal": true,
    ///                     "userName": "sophie",
    ///                     "account": "sophie@example.com",
    ///                     "name": "Sophie",
    ///                     "photosCount": 0,
    ///                     "statusesCount": 0,
    ///                     "followersCount": 0,
    ///                     "followingCount": 0,
    ///                     "includePublicPostsInSearchEngines": false,
    ///                     "includeProfilePageInSearchEngines": false,
    ///                     "activityPubProfile": "https://example.com/actors/sophie",
    ///                     "isSupporterFlagEnabled": false
    ///                 }
    ///             ],
    ///             "readAt": "2026-10-10T10:25:00.000Z"
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 20,
    ///     "total": 1
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 200 (OK) with a paginated collection of `DirectMessageDto`.
    /// - Throws: `DirectMessageError.invalidId` if conversation id is incorrect.
    /// - Throws: `DirectMessageError.invalidPagination` if page is not positive or size is outside the 1–100 range.
    /// - Throws: `DirectMessageError.conversationNotFound` if the conversation is not found in the current user's inbox.
    /// - Throws: `DirectMessageError.messageNotFound` if a message is no longer available while building the response.
    @Sendable
    func statuses(request: Request) async throws -> PaginableResultDto<DirectMessageDto> {
        let parameters = try pagination(request)

        let directMessagesService = request.application.services.directMessagesService
        return try await directMessagesService.messages(conversationId: conversationId(request),
                                                        userId: request.requireUserId(),
                                                        page: parameters.page,
                                                        size: parameters.size,
                                                        on: request.executionContext)
    }

    /// Starting a direct conversation with its first message.
    ///
    /// `recipientIds` is required and selects the explicit audience (at most 100 identifiers).
    /// At least one recipient other than the author must remain after deduplication.
    /// Local recipients who block the author or another selected recipient are excluded independently.
    /// The response lists the accepted recipients; if none remain, the message is rejected.
    /// Text mentions do not grant access. `note` defaults to an empty string and `attachmentIds` to an empty array.
    /// A message must contain text or at least one attachment owned by the author and not yet attached to a status.
    /// Text and attachment counts must respect the server's configured limits.
    /// `replyToStatusId` must be omitted when starting a conversation.
    /// The returned status has `visibility: "mentioned"`; no public timeline entry is created.
    /// Remote recipients receive a signed ActivityPub Create through their personal inboxes, via the delivery queue.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "Content-Type: application/json" \
    /// -d '{"recipientIds": ["7332804261530576897"], "note": "Hello!", "attachmentIds": []}'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "recipientIds": [
    ///         "7332804261530576897"
    ///     ],
    ///     "note": "Hello!",
    ///     "attachmentIds": []
    /// }
    /// ```
    ///
    /// **Example response headers:**
    ///
    /// ```http
    /// HTTP/1.1 201 Created
    /// Location: /api/v1/direct-messages/7333853122610761729
    /// Content-Type: application/json
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333853122610761730",
    ///     "conversationId": "7333853122610761729",
    ///     "status": {
    ///         "id": "7333853122610761730",
    ///         "isLocal": true,
    ///         "note": "Hello!",
    ///         "noteHtml": "<p>Hello!</p>",
    ///         "visibility": "mentioned",
    ///         "sensitive": false,
    ///         "commentsDisabled": false,
    ///         "user": {
    ///             "id": "7267938074834522113",
    ///             "type": "person",
    ///             "url": "https://example.com/@alex",
    ///             "isLocal": true,
    ///             "userName": "alex",
    ///             "account": "alex@example.com",
    ///             "name": "Alex",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/alex",
    ///             "isSupporterFlagEnabled": false
    ///         },
    ///         "activityPubId": "https://example.com/actors/alex/statuses/7333853122610761730",
    ///         "activityPubUrl": "https://example.com/@alex/7333853122610761730",
    ///         "attachments": [],
    ///         "tags": [],
    ///         "repliesCount": 0,
    ///         "reblogsCount": 0,
    ///         "favouritesCount": 0,
    ///         "favourited": false,
    ///         "reblogged": false,
    ///         "bookmarked": false,
    ///         "featured": false,
    ///         "publishedAt": "2026-10-10T10:24:00.000Z",
    ///         "createdAt": "2026-10-10T10:24:00.000Z",
    ///         "updatedAt": "2026-10-10T10:24:00.000Z"
    ///     },
    ///     "recipients": [
    ///         {
    ///             "id": "7332804261530576897",
    ///             "type": "person",
    ///             "url": "https://example.com/@sophie",
    ///             "isLocal": true,
    ///             "userName": "sophie",
    ///             "account": "sophie@example.com",
    ///             "name": "Sophie",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/sophie",
    ///             "isSupporterFlagEnabled": false
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 201 (Created) with `DirectMessageDto` and a Location header pointing to the conversation.
    /// - Throws: `DirectMessageError.invalidId` if a recipient, attachment or reply status id is incorrect.
    /// - Throws: `DirectMessageError.recipientsRequired` if the recipient list exceeds 100 entries or contains no recipient other than the author.
    /// - Throws: `DirectMessageError.emptyMessage` if neither text nor attachments are provided.
    /// - Throws: `DirectMessageError.messageTooLong` if the text exceeds the configured character limit.
    /// - Throws: `DirectMessageError.recipientUnavailable` if the author or a recipient is unavailable, the author blocks a selected recipient, no eligible recipients remain or a remote recipient has no valid inbox.
    /// - Throws: `DirectMessageError.invalidReply` if a reply status id is provided when starting a new conversation.
    /// - Throws: `DirectMessageError.messageNotFound` if the created message is no longer available while building the response.
    /// - Throws: `StatusError.incorrectAttachmentId` if attachment ids contain duplicates.
    /// - Throws: `StatusError.maxLimitOfAttachmentsExceeded` if the attachment count exceeds the configured limit.
    /// - Throws: `StatusError.emailNotVerified` if the author's email address is not verified.
    /// - Throws: `StatusError.accountHasBeenMoved` if the author's account has been moved.
    /// - Throws: `EntityNotFoundError.userNotFound` if the author is not found.
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if an attachment is not found, belongs to another user or is already assigned to a status.
    @Sendable
    func create(request: Request) async throws -> Response {
        let dto = try request.content.decode(DirectMessageRequestDto.self)
        
        let directMessagesService = request.application.services.directMessagesService
        let message = try await directMessagesService.create(basedOn: dto,
                                                             conversationId: nil,
                                                             userId: request.requireUserId(),
                                                             on: request.executionContext)

        return try await created(message: message, on: request)
    }

    /// Sending a new message in an existing direct conversation.
    ///
    /// The `id` path parameter is a `DirectConversation` identifier encoded as a string.
    /// `recipientIds` explicitly selects the audience of this message; previous recipients are not automatically included.
    /// Local recipients who block the author or another selected recipient are excluded independently.
    /// Only this message's selected audience is checked; previous messages and inbox state of excluded recipients are preserved.
    /// New recipients receive this message without access to earlier messages.
    /// `note` defaults to an empty string, `attachmentIds` to an empty array and `replyToStatusId` is optional.
    /// When no parent is selected, the latest message visible to the sender is used for ActivityPub threading.
    /// When supplied, the parent status must be accessible to the author and belong to this conversation.
    /// The same recipient, content and attachment validation applies as when starting a conversation.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/:id/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/7333853122610761729/statuses" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "Content-Type: application/json" \
    /// -d '{"recipientIds": ["7267938074834522113"], "note": "See you tomorrow!", "attachmentIds": [], "replyToStatusId": "7333853122610761730"}'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "recipientIds": [
    ///         "7267938074834522113"
    ///     ],
    ///     "note": "See you tomorrow!",
    ///     "attachmentIds": [],
    ///     "replyToStatusId": "7333853122610761730"
    /// }
    /// ```
    ///
    /// **Example response headers:**
    ///
    /// ```http
    /// HTTP/1.1 201 Created
    /// Location: /api/v1/direct-messages/7333853122610761729
    /// Content-Type: application/json
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333853122610761731",
    ///     "conversationId": "7333853122610761729",
    ///     "status": {
    ///         "id": "7333853122610761731",
    ///         "isLocal": true,
    ///         "note": "See you tomorrow!",
    ///         "noteHtml": "<p>See you tomorrow!</p>",
    ///         "visibility": "mentioned",
    ///         "sensitive": false,
    ///         "commentsDisabled": false,
    ///         "user": {
    ///             "id": "7332804261530576897",
    ///             "type": "person",
    ///             "url": "https://example.com/@sophie",
    ///             "isLocal": true,
    ///             "userName": "sophie",
    ///             "account": "sophie@example.com",
    ///             "name": "Sophie",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/sophie",
    ///             "isSupporterFlagEnabled": false
    ///         },
    ///         "activityPubId": "https://example.com/actors/sophie/statuses/7333853122610761731",
    ///         "activityPubUrl": "https://example.com/@sophie/7333853122610761731",
    ///         "attachments": [],
    ///         "tags": [],
    ///         "repliesCount": 0,
    ///         "reblogsCount": 0,
    ///         "favouritesCount": 0,
    ///         "favourited": false,
    ///         "reblogged": false,
    ///         "bookmarked": false,
    ///         "featured": false,
    ///         "publishedAt": "2026-10-10T10:24:00.000Z",
    ///         "createdAt": "2026-10-10T10:24:00.000Z",
    ///         "updatedAt": "2026-10-10T10:24:00.000Z",
    ///         "replyToStatusId": "7333853122610761730"
    ///     },
    ///     "recipients": [
    ///         {
    ///             "id": "7267938074834522113",
    ///             "type": "person",
    ///             "url": "https://example.com/@alex",
    ///             "isLocal": true,
    ///             "userName": "alex",
    ///             "account": "alex@example.com",
    ///             "name": "Alex",
    ///             "photosCount": 0,
    ///             "statusesCount": 0,
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "includePublicPostsInSearchEngines": false,
    ///             "includeProfilePageInSearchEngines": false,
    ///             "activityPubProfile": "https://example.com/actors/alex",
    ///             "isSupporterFlagEnabled": false
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 201 (Created) with `DirectMessageDto` and a Location header pointing to the conversation.
    /// - Throws: `DirectMessageError.invalidId` if a conversation, recipient, attachment or reply status id is incorrect.
    /// - Throws: `DirectMessageError.recipientsRequired` if the recipient list exceeds 100 entries or contains no recipient other than the author.
    /// - Throws: `DirectMessageError.emptyMessage` if neither text nor attachments are provided.
    /// - Throws: `DirectMessageError.messageTooLong` if the text exceeds the configured character limit.
    /// - Throws: `DirectMessageError.recipientUnavailable` if the author or a recipient is unavailable, the author blocks a selected recipient, no eligible recipients remain or a remote recipient has no valid inbox.
    /// - Throws: `DirectMessageError.conversationNotFound` if the conversation is not found in the current user's inbox.
    /// - Throws: `DirectMessageError.invalidReply` if the selected parent is not visible to the author or belongs to another conversation.
    /// - Throws: `DirectMessageError.messageNotFound` if the created message is no longer available while building the response.
    /// - Throws: `StatusError.incorrectAttachmentId` if attachment ids contain duplicates.
    /// - Throws: `StatusError.maxLimitOfAttachmentsExceeded` if the attachment count exceeds the configured limit.
    /// - Throws: `StatusError.emailNotVerified` if the author's email address is not verified.
    /// - Throws: `StatusError.accountHasBeenMoved` if the author's account has been moved.
    /// - Throws: `EntityNotFoundError.userNotFound` if the author is not found.
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if an attachment is not found, belongs to another user or is already assigned to a status.
    @Sendable
    func reply(request: Request) async throws -> Response {
        let dto = try request.content.decode(DirectMessageRequestDto.self)

        let directMessagesService = request.application.services.directMessagesService
        let message = try await directMessagesService.create(basedOn: dto,
                                                             conversationId: conversationId(request),
                                                             userId: request.requireUserId(),
                                                             on: request.executionContext)

        return try await created(message: message, on: request)
    }

    /// Marking selected direct messages as read.
    ///
    /// The `id` path parameter is a `DirectConversation` identifier encoded as a string.
    /// `statusIds` is required and must contain 1 to 100 accessible status identifiers from this conversation.
    /// Clients should submit only messages actually displayed to the user.
    /// Repeated requests preserve existing `readAt` timestamps. New messages arriving concurrently remain unread.
    /// The conversation's `lastReadAt` is updated for the current user; other users' read state is unaffected.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/:id/read`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/7333853122610761729/read" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "Content-Type: application/json" \
    /// -d '{"statusIds": ["7333853122610761730", "7333853122610761731"]}'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "statusIds": [
    ///         "7333853122610761730",
    ///         "7333853122610761731"
    ///     ]
    /// }
    /// ```
    ///
    /// The successful response has no body (`204 No Content`).
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 204 (No Content).
    /// - Throws: `DirectMessageError.invalidId` if a conversation or status id is incorrect.
    /// - Throws: `DirectMessageError.invalidReadSelection` if the selection contains fewer than 1 or more than 100 entries, or includes messages inaccessible to the user or belonging to another conversation.
    /// - Throws: `DirectMessageError.conversationNotFound` if the conversation is not found in the current user's inbox.
    /// - Throws: `XsrfValidationError.xsrfTokenNotExistsInCookie` if cookie authentication is used without an XSRF cookie.
    /// - Throws: `XsrfValidationError.xsrfTokenNotExistsInHeader` if cookie authentication is used without an XSRF header.
    /// - Throws: `XsrfValidationError.xsrfTokensAreDifferent` if the XSRF cookie and header tokens differ.
    @Sendable
    func markRead(request: Request) async throws -> HTTPStatus {
        let dto = try request.content.decode(DirectConversationReadRequestDto.self)

        let directMessagesService = request.application.services.directMessagesService
        try await directMessagesService.markRead(conversationId: conversationId(request),
                                                 statusIds: dto.statusIds,
                                                 userId: request.requireUserId(),
                                                 on: request.executionContext)

        return .noContent
    }

    /// Updating the current user's direct-conversation mute preference.
    ///
    /// The `id` path parameter is a `DirectConversation` identifier encoded as a string.
    /// `isMuted` is required: use `true` to mute the conversation and `false` to unmute it.
    /// This stores only the current user's preference. Unread state, conversation ordering and other users' preferences
    /// remain unchanged; muted conversations are still included in the unread-conversation counter.
    ///
    /// > Important: Endpoint URL: `/api/v1/direct-messages/:id/mute`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/direct-messages/7333853122610761729/mute" \
    /// -X PUT \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "Content-Type: application/json" \
    /// -d '{"isMuted": true}'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "isMuted": true
    /// }
    /// ```
    ///
    /// The successful response has no body (`204 No Content`).
    ///
    /// - Parameter request: Request from the authenticated user.
    /// - Returns: 204 (No Content).
    /// - Throws: `DirectMessageError.invalidId` if conversation id is incorrect.
    /// - Throws: `DirectMessageError.conversationNotFound` if the conversation is not found in the current user's inbox.
    @Sendable
    func mute(request: Request) async throws -> HTTPStatus {
        let dto = try request.content.decode(DirectConversationMuteRequestDto.self)

        let directMessagesService = request.application.services.directMessagesService
        try await directMessagesService.mute(conversationId: conversationId(request),
                                             userId: request.requireUserId(),
                                             isMuted: dto.isMuted,
                                             on: request.executionContext)

        return .noContent
    }

    private func conversationId(_ request: Request) throws -> Int64 {
        guard let value = request.parameters.get("id"), let id = value.toId(), id > 0 else {
            throw DirectMessageError.invalidId
        }

        return id
    }

    private func pagination(_ request: Request) throws -> (page: Int, size: Int) {
        let page = try request.query.get(Int?.self, at: "page") ?? 1
        let size = try request.query.get(Int?.self, at: "size") ?? 20

        return (page, size)
    }

    private func created(message: DirectMessageDto, on request: Request) async throws -> Response {
        let response = try await message.encodeResponse(status: .created, for: request)
        response.headers.replaceOrAdd(name: .location, value: "/api/v1/direct-messages/\(message.conversationId)")

        return response
    }
}
