//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension StatusesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("statuses")
    
    func boot(routes: RoutesBuilder) throws {
        let statusesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(StatusesController.uri)
            .grouped(UserAuthenticator())
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesCreate))
            .post(use: create)
        
        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesList))
            .get(use: list)
        
        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesRead))
            .get(":id", use: read)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesDelete))
            .delete(":id", use: delete)

        statusesGroup
            .grouped(EventHandlerMiddleware(.statusesContext))
            .get(":id", "context", use: context)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesReblog))
            .post(":id", "reblog", use: reblog)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnreblog))
            .post(":id", "unreblog", use: unreblog)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesReblogged))
            .get(":id", "reblogged", use: reblogged)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFavourite))
            .post(":id", "favourite", use: favourite)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnfavourite))
            .post(":id", "unfavourite", use: unfavourite)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFavourited))
            .get(":id", "favourited", use: favourited)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesBookmark))
            .post(":id", "bookmark", use: bookmark)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnbookmark))
            .post(":id", "unbookmark", use: unbookmark)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.statusesFeature))
            .post(":id", "feature", use: feature)
        
        statusesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.statusesUnfeature))
            .post(":id", "unfeature", use: unfeature)
    }
}

/// Operations on statuses.
///
/// The controller supports multiple operations to manage statuses.
/// It allows adding/deleting statuses, liking, sharing, etc.
///
/// > Important: Base controller URL: `/api/v1/statuses`.
final class StatusesController {
    
    /// Create new status.
    ///
    /// Endpoint to create a new status. Previously, attachments must be uploaded
    /// ``AttachmentsController/upload(request:)`` and here only their
    /// `id` numbers are uploaded.
    ///
    /// Visibility is one of following value:
    ///
    /// - `public` - status visible for all users
    /// - `followers` - status visible only for followers
    /// - `mentioned` - status visible only for mentioned users
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses" \
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
    ///     "note": "Status text",
    ///     "visibility": "public",
    ///     "sensitive": true,
    ///     "commentsDisabled": false,
    ///     "attachmentIds": [
    ///         "7333853122610388993"
    ///     ],
    ///     "categoryId": "7302167186067830785",
    ///     "contentWarning": "This photo contains nudity."
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///             "description": "Image",
    ///             "id": "7333853122610388993",
    ///             "license": {
    ///                 "code": "CC BY-SA",
    ///                 "id": "7310942225159069697",
    ///                 "name": "Attribution-ShareAlike",
    ///                 "url": "https://creativecommons.org/licenses/by-sa/4.0/"
    ///             },
    ///             "location": {
    ///                 "country": {
    ///                     "code": "PL",
    ///                     "id": "7257110629787191297",
    ///                     "name": "Poland"
    ///                 },
    ///                 "id": "7257110934739898369",
    ///                 "latitude": "51,1",
    ///                 "longitude": "17,03333",
    ///                 "name": "Wrocław"
    ///             },
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2022-10-20T14:24:51.037+02:00",
    ///                     "exposureTime": "1/500",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "100"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 1.4998169168802635,
    ///                 "height": 2731,
    ///                 "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                 "width": 4096
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 1.5009380863039399,
    ///                 "height": 533,
    ///                 "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/4aff6ec34865483ab2e6b3b145826e46.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": false,
    ///     "category": {
    ///         "id": "7302167186067830785",
    ///         "name": "Street"
    ///     },
    ///     "commentsDisabled": false,
    ///     "contentWarning": "This photo contains nudity.",
    ///     "createdAt": "2024-02-10T06:16:39.852Z",
    ///     "favourited": false,
    ///     "favouritesCount": 0,
    ///     "featured": false,
    ///     "id": "7333853122610761729",
    ///     "isLocal": true,
    ///     "note": "Status text",
    ///     "noteHtml": "<p>Status text</p>",
    ///     "reblogged": false,
    ///     "reblogsCount": 0,
    ///     "repliesCount": 0,
    ///     "sensitive": true,
    ///     "tags": [],
    ///     "updatedAt": "2024-02-10T06:16:39.852Z",
    ///     "user": { ... },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``StatusRequestDto``.
    ///
    /// - Returns: Information about newly added status.
    ///
    /// - Throws: `Validation.validationError` if validation errors occurs.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `StatusError.attachmentsAreRequired` if attachments are misssing.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    /// - Throws: `StatusError.incorrectAttachmentId` if incorrect attachment id.
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if attachment not exists.
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw EntityNotFoundError.userNotFound
        }
        
        let statusRequestDto = try request.content.decode(StatusRequestDto.self)
        try StatusRequestDto.validate(content: request)
        
        // Attachments can be ommited only for statused added as a comment to other status.
        if statusRequestDto.attachmentIds.count == 0 {
            guard let replyToStatusId = statusRequestDto.replyToStatusId?.toId() else {
                throw StatusError.attachmentsAreRequired
            }
            
            guard let _ = try await Status.find(replyToStatusId, on: request.db) else {
                throw EntityNotFoundError.statusNotFound
            }
        }
        
        // Verify attachments ids.
        var attachments: [Attachment] = []
        for attachmentId in statusRequestDto.attachmentIds {
            guard let attachmentId = attachmentId.toId() else {
                throw StatusError.incorrectAttachmentId
            }
            
            let attachment = try await Attachment.query(on: request.db)
                .filter(\.$id == attachmentId)
                .filter(\.$user.$id == authorizationPayloadId)
                .filter(\.$status.$id == nil)
                .with(\.$originalFile)
                .with(\.$smallFile)
                .with(\.$exif)
                .with(\.$license)
                .with(\.$location) { location in
                    location.with(\.$country)
                }
                .first()
            
            guard let attachment else {
                throw EntityNotFoundError.attachmentNotFound
            }
            
            attachments.append(attachment)
        }
        
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let attachmentsFromDatabase = attachments
        let status = Status(isLocal: true,
                            userId: authorizationPayloadId,
                            note: statusRequestDto.note,
                            baseAddress: baseAddress,
                            userName: user.userName,
                            application: request.applicationName,
                            categoryId: statusRequestDto.categoryId?.toId(),
                            visibility: statusRequestDto.visibility.translate(),
                            sensitive: statusRequestDto.sensitive,
                            contentWarning: statusRequestDto.contentWarning,
                            commentsDisabled: statusRequestDto.commentsDisabled,
                            replyToStatusId: statusRequestDto.replyToStatusId?.toId())
        
        // Save status and attachments into database (in one transaction).
        try await request.db.transaction { database in
            try await status.create(on: database)
            
            for attachment in attachmentsFromDatabase {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }
            
            let hashtags = status.note?.getHashtags() ?? []
            for hashtag in hashtags {
                let statusHashtag = try StatusHashtag(statusId: status.requireID(), hashtag: hashtag)
                try await statusHashtag.save(on: database)
            }
            
            let userNames = status.note?.getUserNames() ?? []
            for userName in userNames {
                let statusMention = try StatusMention(statusId: status.requireID(), userName: userName)
                try await statusMention.save(on: database)
            }
            
            try await request.application.services.statusesService.updateStatusCount(on: database, for: authorizationPayloadId)
            
            if let statusId = status.id {
                try await request
                    .queues(.statusSender)
                    .dispatch(StatusSenderJob.self, statusId)
            }
        }
        
        let statusFromDatabase = try await request.application.services.statusesService.get(on: request.db, id: status.requireID())
        guard let statusFromDatabase else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Prepare and return status.
        let response = try await self.createNewStatusResponse(on: request, status: statusFromDatabase, attachments: attachmentsFromDatabase)
        return response
    }
    
    /// Exposing list of statuses.
    ///
    /// The endpoint returns a list of statuses from the system. For a logged-in user,
    /// public statuses are returned, as well as any statuses that he has added.
    /// For anonymous users, only public statuses are returned.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses" \
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
    ///             "application": "Vernissage 1.0.0-alpha1",
    ///             "attachments": [
    ///                 {
    ///                     "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///                     "description": "Image",
    ///                     "id": "7333853122610388993",
    ///                     "license": {
    ///                         "code": "CC BY-SA",
    ///                         "id": "7310942225159069697",
    ///                         "name": "Attribution-ShareAlike",
    ///                         "url": "https://creativecommons.org/licenses/by-sa/4.0/"
    ///                     },
    ///                     "location": {
    ///                         "country": {
    ///                             "code": "PL",
    ///                             "id": "7257110629787191297",
    ///                             "name": "Poland"
    ///                         },
    ///                         "id": "7257110934739898369",
    ///                         "latitude": "51,1",
    ///                         "longitude": "17,03333",
    ///                         "name": "Wrocław"
    ///                     },
    ///                     "metadata": {
    ///                         "exif": {
    ///                             "createDate": "2022-10-20T14:24:51.037+02:00",
    ///                             "exposureTime": "1/500",
    ///                             "fNumber": "f/8",
    ///                             "focalLenIn35mmFilm": "85",
    ///                             "lens": "Zeiss Batis 1.8/85",
    ///                             "make": "SONY",
    ///                             "model": "ILCE-7M4",
    ///                             "photographicSensitivity": "100"
    ///                         }
    ///                     },
    ///                     "originalFile": {
    ///                         "aspect": 1.4998169168802635,
    ///                         "height": 2731,
    ///                         "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                         "width": 4096
    ///                     },
    ///                     "smallFile": {
    ///                         "aspect": 1.5009380863039399,
    ///                         "height": 533,
    ///                         "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/4aff6ec34865483ab2e6b3b145826e46.jpg",
    ///                         "width": 800
    ///                     }
    ///                 }
    ///             ],
    ///             "bookmarked": false,
    ///             "commentsDisabled": false,
    ///             "contentWarning": "This photo contains nudity.",
    ///             "createdAt": "2024-02-10T06:16:39.852Z",
    ///             "favourited": false,
    ///             "favouritesCount": 0,
    ///             "featured": false,
    ///             "id": "7333853122610761729",
    ///             "isLocal": true,
    ///             "note": "Status text",
    ///             "noteHtml": "<p>Status text</p>",
    ///             "reblogged": false,
    ///             "reblogsCount": 0,
    ///             "repliesCount": 0,
    ///             "sensitive": true,
    ///             "tags": [],
    ///             "updatedAt": "2024-02-10T06:16:39.852Z",
    ///             "user": { ... },
    ///             "visibility": "public"
    ///         }
    ///     ],
    ///     "maxId": "7333853122610761729",
    ///     "minId": "7333853122610761729"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable statuses.
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let statusesService = request.application.services.statusesService
        let authorizationPayloadId = request.userId
        let linkableParams = request.linkableParams()

        if let authorizationPayloadId {
            // For signed in users we can return public statuses and all his own statuses.
            let linkableStatuses = try await statusesService.statuses(for: authorizationPayloadId, linkableParams: linkableParams, on: request)
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        } else {
            // For anonymous users we can return only public statuses.
            let linkableStatuses = try await statusesService.statuses(linkableParams: linkableParams, on: request)
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        }
    }
    
    /// Get specific status.
    ///
    /// This endpoint returns a single status. The user must have access to the status.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7333853122610761729" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///             "description": "Image",
    ///             "id": "7333853122610388993",
    ///             "license": {
    ///                 "code": "CC BY-SA",
    ///                 "id": "7310942225159069697",
    ///                 "name": "Attribution-ShareAlike",
    ///                 "url": "https://creativecommons.org/licenses/by-sa/4.0/"
    ///             },
    ///             "location": {
    ///                 "country": {
    ///                     "code": "PL",
    ///                     "id": "7257110629787191297",
    ///                     "name": "Poland"
    ///                 },
    ///                 "id": "7257110934739898369",
    ///                 "latitude": "51,1",
    ///                 "longitude": "17,03333",
    ///                 "name": "Wrocław"
    ///             },
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2022-10-20T14:24:51.037+02:00",
    ///                     "exposureTime": "1/500",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "100"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 1.4998169168802635,
    ///                 "height": 2731,
    ///                 "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                 "width": 4096
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 1.5009380863039399,
    ///                 "height": 533,
    ///                 "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/4aff6ec34865483ab2e6b3b145826e46.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": false,
    ///     "category": {
    ///         "id": "7302167186067830785",
    ///         "name": "Street"
    ///     },
    ///     "commentsDisabled": false,
    ///     "contentWarning": "This photo contains nudity.",
    ///     "createdAt": "2024-02-10T06:16:39.852Z",
    ///     "favourited": false,
    ///     "favouritesCount": 0,
    ///     "featured": false,
    ///     "id": "7333853122610761729",
    ///     "isLocal": true,
    ///     "note": "Status text",
    ///     "noteHtml": "<p>Status text</p>",
    ///     "reblogged": false,
    ///     "reblogsCount": 0,
    ///     "repliesCount": 0,
    ///     "sensitive": true,
    ///     "tags": [],
    ///     "updatedAt": "2024-02-10T06:16:39.852Z",
    ///     "user": { ... },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about single status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func read(request: Request) async throws -> StatusDto {
        let authorizationPayloadId = request.userId

        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        if let authorizationPayloadId {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$category)
                .with(\.$user)
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            let statusServices = request.application.services.statusesService
            let canView = try await statusServices.can(view: status, authorizationPayloadId: authorizationPayloadId, on: request)
            guard canView else {
                throw EntityNotFoundError.statusNotFound
            }
            
            return await statusServices.convertToDto(on: request, status: status, attachments: status.attachments)
        } else {
            let status = try await Status.query(on: request.db)
                .filter(\.$id == statusId)
                .filter(\.$visibility ~~ [.public])
                .with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$category)
                .with(\.$user)
                .first()

            guard let status else {
                throw EntityNotFoundError.statusNotFound
            }
            
            let statusServices = request.application.services.statusesService
            return await statusServices.convertToDto(on: request, status: status, attachments: status.attachments)
        }
    }
    
    /// Delete specific status.
    ///
    /// This endpoint is used to delete statuses. The status can be deleted by the user
    /// who submitted it or by a moderator or administrator.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7333853122610761729" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    /// - Throws: `EntityForbiddenError.statusForbidden` if access to specified status is forbidden.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }

        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let status = try await Status.query(on: request.db)
            .filter(\.$id == statusId)
            .with(\.$user)
            .first()
        
        guard let status else {
            throw EntityNotFoundError.statusNotFound
        }
        
        guard status.$user.id == authorizationPayloadId || request.isModerator || request.isAdministrator else {
            throw EntityForbiddenError.statusForbidden
        }
        
        let statusServices = request.application.services.statusesService
        try await statusServices.delete(id: statusId, on: request.db)
                
        if status.isLocal {
            try await request
                .queues(.statusDeleter)
                .dispatch(StatusDeleterJob.self, StatusDeleteJobDto(userId: status.user.requireID(), activityPubStatusId: status.activityPubId))
        }

        return HTTPStatus.ok
    }
    
    /// Status context. View statuses above and below this status in the thread.
    ///
    /// The endpoint is used to retrieve a tree of comments added to a specific status.
    /// Each comment is also a status, so you can also retrieve comments assigned to
    /// that status, and so on.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/context`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7333853122610761729/context" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "ancestors": [],
    ///     "descendants": [
    ///         {
    ///             "application": "Vernissage 1.0.0-alpha1",
    ///             "attachments": [],
    ///             "bookmarked": false,
    ///             "commentsDisabled": false,
    ///             "createdAt": "2023-11-15T14:34:43.679Z",
    ///             "favourited": false,
    ///             "favouritesCount": 0,
    ///             "featured": false,
    ///             "id": "7301697226451517441",
    ///             "isLocal": true,
    ///             "note": "This is great picture!",
    ///             "noteHtml": "<p>This is great picture!</p>",
    ///             "reblogged": false,
    ///             "reblogsCount": 0,
    ///             "repliesCount": 0,
    ///             "sensitive": false,
    ///             "tags": [],
    ///             "updatedAt": "2023-11-15T14:34:43.679Z",
    ///             "user": { ... },
    ///             "visibility": "public"
    ///         },
    ///         {
    ///             "application": "Vernissage 1.0.0-alpha1",
    ///             "attachments": [],
    ///             "bookmarked": false,
    ///             "commentsDisabled": false,
    ///             "createdAt": "2023-11-15T14:50:38.557Z",
    ///             "favourited": false,
    ///             "favouritesCount": 0,
    ///             "featured": false,
    ///             "id": "7301701383979831297",
    ///             "isLocal": true,
    ///             "note": "Thank you!",
    ///             "noteHtml": "<p>Thank you!</p>",
    ///             "reblogged": false,
    ///             "reblogsCount": 0,
    ///             "repliesCount": 0,
    ///             "sensitive": false,
    ///             "tags": [],
    ///             "updatedAt": "2023-11-15T14:50:38.557Z",
    ///             "user": { ... },
    ///             "visibility": "public"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of ancestors and descendats.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    func context(request: Request) async throws -> StatusContextDto {
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let ancestors = try await statusesService.ancestors(for: statusId, on: request.db)
        let descendants = try await statusesService.descendants(for: statusId, on: request.db)
        
        let ancestorsDtos = await statusesService.convertToDtos(on: request, statuses: ancestors)
        let descendantsDtos = await statusesService.convertToDtos(on: request, statuses: descendants)
        
        return StatusContextDto(ancestors: ancestorsDtos, descendants: descendantsDtos)
    }
    
    /// Reblog (boost) specific status.
    ///
    /// This endpoint allows you to share with status with other users who are following
    /// the logged-in user.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/reblog`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/reblog" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": false,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": false,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 10,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about reblogged status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    /// - Throws: `StatusError.cannotReblogComments` if reblogged status is a comment.
    /// - Throws: `StatusError.cannotReblogMentionedStatus` if reblogged status has mentioned visibility.
    func reblog(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let user = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        // We have to reblog orginal status, even when we get here already reblogged status.
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeReblog = try await statusesService.getOrginalStatus(id: statusId, on: request.db)
        guard let statusFromDatabaseBeforeReblog else {
            throw EntityNotFoundError.statusNotFound
        }

        // We cannot reblogs comments (there is no place wehere we can see them).
        guard statusFromDatabaseBeforeReblog.$replyToStatus.id == nil else {
            throw StatusError.cannotReblogComments
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeReblog, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Even if user have access to mentioned status, he/she shouldn't reblog it.
        guard statusFromDatabaseBeforeReblog.visibility != .mentioned else {
            throw StatusError.cannotReblogMentionedStatus
        }

        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let reblogRequestDto = try request.content.decode(ReblogRequestDto?.self)

        let status = Status(isLocal: true,
                            userId: authorizationPayloadId,
                            note: nil,
                            baseAddress: baseAddress,
                            userName: user.userName,
                            application: request.applicationName,
                            categoryId: nil,
                            visibility: (reblogRequestDto?.visibility ?? .public).translate(),
                            reblogId: statusId)
        
        // Save status and recalculate reblogs count.
        try await status.create(on: request.db)
        try await statusesService.updateReblogsCount(for: statusId, on: request.db)
        
        // Add new notification.
        let notificationsService = request.application.services.notificationsService
        try await notificationsService.create(type: .reblog,
                                              to: statusFromDatabaseBeforeReblog.user,
                                              by: authorizationPayloadId,
                                              statusId: statusId,
                                              on: request.db)
        
        try await request
            .queues(.statusReblogger)
            .dispatch(StatusRebloggerJob.self, status.requireID())
        
        // Prepare and return status.
        let statusFromDatabaseAfterReblog = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterReblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterReblog,
                                                   attachments: statusFromDatabaseAfterReblog.attachments)
    }
    
    /// Unreblog (revert boost) specific status.
    ///
    /// This endpoint allows you to undo the sharing of a given status with
    /// other users who are following the logged-in user.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/unreblog`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/unreblog" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": false,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": false,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": false,
    ///     "reblogsCount": 9,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func unreblog(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        // We have to unreblog reblog status, even when we get here orginal status.
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnreblog = try await statusesService.getReblogStatus(id: statusId, userId: authorizationPayloadId, on: request.db)
        guard let statusFromDatabaseBeforeUnreblog else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Download main (reblogged) status.
        guard let mainStatusId = statusFromDatabaseBeforeUnreblog.$reblog.id,
              let mainStatus = try await statusesService.get(on: request.db, id: mainStatusId) else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // Delete reblog status from database.
        try await statusesService.delete(id: statusFromDatabaseBeforeUnreblog.requireID(), on: request.db)
        try await statusesService.updateReblogsCount(for: mainStatusId, on: request.db)
        
        // Delete notification about reblog.
        let notificationsService = request.application.services.notificationsService
        try await notificationsService.delete(type: .reblog,
                                              to: mainStatus.$user.id,
                                              by: authorizationPayloadId,
                                              statusId: mainStatusId,
                                              on: request.db)
        
        let activityPubUnreblogDto = try ActivityPubUnreblogDto(activityPubStatusId: statusFromDatabaseBeforeUnreblog.activityPubId,
                                                                activityPubProfile: statusFromDatabaseBeforeUnreblog.user.activityPubProfile,
                                                                published: statusFromDatabaseBeforeUnreblog.createdAt ?? Date(),
                                                                activityPubReblogProfile: mainStatus.user.activityPubProfile,
                                                                activityPubReblogStatusId: mainStatus.activityPubId,
                                                                statusId: statusFromDatabaseBeforeUnreblog.requireID(),
                                                                userId: authorizationPayloadId,
                                                                orginalStatusId: mainStatusId)
        
        try await request
            .queues(.statusUnreblogger)
            .dispatch(StatusUnrebloggerJob.self, activityPubUnreblogDto)
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnreblog = try await statusesService.get(on: request.db, id: mainStatusId)
        guard let statusFromDatabaseAfterUnreblog else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnreblog,
                                                   attachments: statusFromDatabaseAfterUnreblog.attachments)
    }
    
    /// Users who reblogged status.
    ///
    /// This endpoint returns information about users who have shared
    /// a given status with their followers.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/reblogged`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7310634817170980865/reblogged" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/cd743f07793747daa7d9aa7662b78f7a.jpeg",
    ///             "bio": "<p>This is a bio.</p>",
    ///             "bioHtml": "<p><This is a bio.</p>",
    ///             "createdAt": "2023-07-27T15:39:47.627Z",
    ///             "fields": [],
    ///             "followersCount": 1,
    ///             "followingCount": 1,
    ///             "headerUrl": "https://example.com/ab01b3185a82430788016f4072d5d81b.jpg",
    ///             "id": "7260522736489424897",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:22.711Z",
    ///             "userName": "johndoe@example.com"
    ///         }
    ///     ],
    ///     "maxId": "7317208934634969089",
    ///     "minId": "7317208934634969089"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    func reblogged(request: Request) async throws -> LinkableResultDto<UserDto> {
        let linkableParams = request.linkableParams()
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let linkableUsers = try await statusesService.reblogged(on: request, statusId: statusId, linkableParams: linkableParams)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }
    
    /// Favourite specific status.
    ///
    /// This endpoint is used to like a given status. The liking information is public
    /// and visible by other users. The author of the status also gets a notification
    /// that the status has been liked.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/favourite`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7301745982919989249/favourite" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [],
    ///     "bookmarked": false,
    ///     "commentsDisabled": false,
    ///     "createdAt": "2023-11-15T17:44:10.973Z",
    ///     "favourited": true,
    ///     "favouritesCount": 31,
    ///     "featured": false,
    ///     "id": "7301745982919989249",
    ///     "isLocal": true,
    ///     "note": "This is a great picture",
    ///     "noteHtml": "<p>This is a great picture</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 21,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-11-15T17:44:10.973Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T13:52:27.590Z",
    ///         "followersCount": 0,
    ///         "followingCount": 0,
    ///         "id": "7260124605905795073",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 4,
    ///         "updatedAt": "2023-12-09T13:49:39.035Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about favourited status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func favourite(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeFavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeFavourite else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeFavourite, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            // Save information about new favourite.
            let statusFavourite = StatusFavourite(statusId: statusId, userId: authorizationPayloadId)
            try await statusFavourite.save(on: request.db)
            try await statusesService.updateFavouritesCount(for: statusId, on: request.db)
            
            // Add new notification.
            let notificationsService = request.application.services.notificationsService
            try await notificationsService.create(type: .favourite,
                                                  to: statusFromDatabaseBeforeFavourite.user,
                                                  by: authorizationPayloadId,
                                                  statusId: statusId,
                                                  on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterFavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterFavourite else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterFavourite,
                                                   attachments: statusFromDatabaseAfterFavourite.attachments)
    }
    
    /// Unfavourite specific status.
    ///
    /// This endpoint serves to withdraw the liking of a given status.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/unfavourite`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7301745982919989249/unfavourite" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [],
    ///     "bookmarked": false,
    ///     "commentsDisabled": false,
    ///     "createdAt": "2023-11-15T17:44:10.973Z",
    ///     "favourited": false,
    ///     "favouritesCount": 30,
    ///     "featured": false,
    ///     "id": "7301745982919989249",
    ///     "isLocal": true,
    ///     "note": "This is a great picture",
    ///     "noteHtml": "<p>This is a great picture</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 21,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-11-15T17:44:10.973Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T13:52:27.590Z",
    ///         "followersCount": 0,
    ///         "followingCount": 0,
    ///         "id": "7260124605905795073",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 4,
    ///         "updatedAt": "2023-12-09T13:49:39.035Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func unfavourite(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnfavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnfavourite else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnfavourite, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let statusFavourite = try await StatusFavourite.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            // Delete information about favourite.
            try await statusFavourite.delete(on: request.db)
            try await statusesService.updateFavouritesCount(for: statusId, on: request.db)
            
            // Delete notification about favourite.
            let notificationsService = request.application.services.notificationsService
            try await notificationsService.delete(type: .favourite,
                                                  to: statusFromDatabaseBeforeUnfavourite.$user.id,
                                                  by: authorizationPayloadId,
                                                  statusId: statusId,
                                                  on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnfavourite = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnfavourite else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnfavourite,
                                                   attachments: statusFromDatabaseAfterUnfavourite.attachments)
    }
    
    /// Users who favourited status.
    ///
    /// This endpoint returns information about users who have favourited
    /// a given status.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/favourited`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7310634817170980865/favourited" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/cd743f07793747daa7d9aa7662b78f7a.jpeg",
    ///             "bio": "<p>This is a bio.</p>",
    ///             "bioHtml": "<p><This is a bio.</p>",
    ///             "createdAt": "2023-07-27T15:39:47.627Z",
    ///             "fields": [],
    ///             "followersCount": 1,
    ///             "followingCount": 1,
    ///             "headerUrl": "https://example.com/ab01b3185a82430788016f4072d5d81b.jpg",
    ///             "id": "7260522736489424897",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:22.711Z",
    ///             "userName": "johndoe@example.com"
    ///         }
    ///     ],
    ///     "maxId": "7317208934634969089",
    ///     "minId": "7317208934634969089"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    func favourited(request: Request) async throws -> LinkableResultDto<UserDto> {
        let linkableParams = request.linkableParams()
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let linkableUsers = try await statusesService.favourited(on: request, statusId: statusId, linkableParams: linkableParams)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }

    /// Bookmark specific status.
    ///
    /// This endpoint is used to add a given status to your bookmarks.
    /// The list of such statuses is private, no one else can see what statuses
    /// a logged-in user has on their list.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/bookmark`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/bookmark" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": true,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": false,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 10,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about bookmarked status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func bookmark(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeBookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeBookmark else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeBookmark, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            let statusBookmark = StatusBookmark(statusId: statusId, userId: authorizationPayloadId)
            try await statusBookmark.save(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterBookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterBookmark else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request, status: statusFromDatabaseAfterBookmark, attachments: statusFromDatabaseAfterBookmark.attachments)
    }
    
    /// Unbookmark specific status.
    ///
    /// This endpoint is used to remove the status from the bookmark list.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/unbookmark`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/unbookmark" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": false,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": false,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 10,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about bookmarked status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func unbookmark(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnbookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnbookmark else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnbookmark, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let statusBookmark = try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            try await statusBookmark.delete(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnbookmark = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnbookmark else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnbookmark,
                                                   attachments: statusFromDatabaseAfterUnbookmark.attachments)
    }
    
    /// Feature specific status.
    ///
    /// This endpoint is used to add the status to a special list of featured statuses.
    /// Only moderators and administrators have access to this endpoint.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/feature`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/feature" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": true,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": true,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 10,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about featured status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func feature(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeFeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeFeature else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeFeature, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() == nil {
            let featuredStatus = FeaturedStatus(statusId: statusId, userId: authorizationPayloadId)
            try await featuredStatus.save(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterFeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterFeature else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request, status: statusFromDatabaseAfterFeature, attachments: statusFromDatabaseAfterFeature.attachments)
    }
    
    /// Unfeature specific status.
    ///
    /// This endpoint is used to delete  the status from a special list of featured statuses.
    /// Only moderators and administrators have access to this endpoint.
    ///
    /// > Important: Endpoint URL: `/api/v1/statuses/:id/unfeature`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/statuses/7268344623554775041/unfeature" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "application": "Vernissage 1.0.0-alpha1",
    ///     "attachments": [
    ///         {
    ///             "blurhash": "UYG8=p^+xaRi9u%NRjIU~qxva~WAXAt8ofWB",
    ///             "description": "This is a photo of the cat",
    ///             "id": "7268344623554553857",
    ///             "metadata": {
    ///                 "exif": {
    ///                     "createDate": "2023-05-27T10:20:13.500+02:00",
    ///                     "exposureTime": "1/250",
    ///                     "fNumber": "f/8",
    ///                     "focalLenIn35mmFilm": "85",
    ///                     "lens": "Zeiss Batis 1.8/85",
    ///                     "make": "SONY",
    ///                     "model": "ILCE-7M4",
    ///                     "photographicSensitivity": "640"
    ///                 }
    ///             },
    ///             "originalFile": {
    ///                 "aspect": 0.666748046875,
    ///                 "height": 4096,
    ///                 "url": "https://example.com/1a864236349543938875feebc84caa54.jpg",
    ///                 "width": 2731
    ///             },
    ///             "smallFile": {
    ///                 "aspect": 0.6672226855713094,
    ///                 "height": 1199,
    ///                 "url": "https://example.com/c4f2ca8176b04bf49f1243d0fec3e4f0.jpg",
    ///                 "width": 800
    ///             }
    ///         }
    ///     ],
    ///     "bookmarked": true,
    ///     "commentsDisabled": false,
    ///     "contentWarning": "",
    ///     "createdAt": "2023-08-17T17:30:43.546Z",
    ///     "favourited": true,
    ///     "favouritesCount": 12,
    ///     "featured": false,
    ///     "id": "7268344623554775041",
    ///     "isLocal": true,
    ///     "note": "Marcin divider",
    ///     "noteHtml": "<p>Marcin divider</p>",
    ///     "reblogged": true,
    ///     "reblogsCount": 10,
    ///     "repliesCount": 0,
    ///     "sensitive": false,
    ///     "tags": [],
    ///     "updatedAt": "2023-08-17T17:30:43.546Z",
    ///     "user": {
    ///         "account": "johndoe@example.com",
    ///         "activityPubProfile": "http://example.com/actors/johndoe",
    ///         "createdAt": "2023-07-26T12:13:40.336Z",
    ///         "followersCount": 1,
    ///         "followingCount": 1,
    ///         "id": "7260098629943709697",
    ///         "isLocal": true,
    ///         "name": "John Doe",
    ///         "statusesCount": 13,
    ///         "updatedAt": "2023-07-26T12:13:40.336Z",
    ///         "userName": "johndoe"
    ///     },
    ///     "visibility": "public"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about status.
    ///
    /// - Throws: `StatusError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    func unfeature(request: Request) async throws -> StatusDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let statusIdString = request.parameters.get("id", as: String.self) else {
            throw StatusError.incorrectStatusId
        }
        
        guard let statusId = statusIdString.toId() else {
            throw StatusError.incorrectStatusId
        }
        
        let statusesService = request.application.services.statusesService
        let statusFromDatabaseBeforeUnfeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseBeforeUnfeature else {
            throw EntityNotFoundError.statusNotFound
        }
        
        // We have to verify if user have access to the status (it's not only for mentioned).
        let canView = try await statusesService.can(view: statusFromDatabaseBeforeUnfeature, authorizationPayloadId: authorizationPayloadId, on: request)
        guard canView else {
            throw EntityNotFoundError.statusNotFound
        }
        
        if let featuredStatus = try await FeaturedStatus.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$status.$id == statusId)
            .first() {
            try await featuredStatus.delete(on: request.db)
        }
        
        // Prepare and return status.
        let statusFromDatabaseAfterUnfeature = try await statusesService.get(on: request.db, id: statusId)
        guard let statusFromDatabaseAfterUnfeature else {
            throw EntityNotFoundError.statusNotFound
        }

        return await statusesService.convertToDto(on: request,
                                                   status: statusFromDatabaseAfterUnfeature,
                                                   attachments: statusFromDatabaseAfterUnfeature.attachments)
    }
    
    private func createNewStatusResponse(on request: Request, status: Status, attachments: [Attachment]) async throws -> Response {
        let statusServices = request.application.services.statusesService
        let createdStatusDto = await statusServices.convertToDto(on: request, status: status, attachments: attachments)

        let response = try await createdStatusDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(StatusesController.uri)/\(status.stringId() ?? "")")
        response.status = .created

        return response
    }
}