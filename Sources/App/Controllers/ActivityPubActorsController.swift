//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

/// Controller for support od basic ActivityPub endpoints.
final class ActivityPubActorsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("actors")
    private let orderdCollectionSize = 10
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubGroup = routes.grouped(ActivityPubActorsController.uri)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubRead))
            .get(":name", use: read)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubInbox))
            .post(":name", "inbox", use: inbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubOutbox))
            .post(":name", "outbox", use: outbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowing))
            .get(":name", "following", use: following)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowers))
            .get(":name", "followers", use: followers)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubLiked))
            .get(":name", "liked", use: liked)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubLiked))
            .get(":name", "statuses", ":id", use: status)
    }
    
    /// Returns user ActivityPub profile.
    func read(request: Request) async throws -> PersonDto {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.get(on: request.db, userName: userName)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let appplicationSettings = request.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let attachments = try await user.$flexiFields.get(on: request.db)
        let hashtags = try await user.$hashtags.get(on: request.db)
        
        return PersonDto(id: user.activityPubProfile,
                         following: "\(user.activityPubProfile)/following",
                         followers: "\(user.activityPubProfile)/followers",
                         inbox: "\(user.activityPubProfile)/inbox",
                         outbox: "\(user.activityPubProfile)/outbox",
                         preferredUsername: user.userName,
                         name: user.name ?? user.userName,
                         summary: user.bio ?? "",
                         url: "\(baseAddress)/@\(user.userName)",
                         manuallyApprovesFollowers: user.manuallyApprovesFollowers,
                         publicKey: PersonPublicKeyDto(id: "\(user.activityPubProfile)#main-key",
                                                       owner: user.activityPubProfile,
                                                       publicKeyPem: user.publicKey ?? ""),
                         icon: self.getPersonImage(for: user.avatarFileName, on: request),
                         image: self.getPersonImage(for: user.headerFileName, on: request),
                         endpoints: PersonEndpointsDto(sharedInbox: "\(baseAddress)/shared/inbox"),
                         attachment: attachments.map({ PersonAttachmentDto(name: $0.key ?? "", value: $0.value ?? "") }),
                         tag: hashtags.map({ PersonHashtagDto(type: .hashtag, name: $0.hashtag, href: "\(baseAddress)/tags/\($0.hashtag)") })
        )
    }
        
    /// User ActivityPub inbox.
    func inbox(request: Request) async throws -> HTTPStatus {
        request.logger.info("\(request.headers.description)")
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("User inbox activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       httpMethod: .post,
                                                       httpPath: .userInbox(userName))

        try await request
            .queues(.apUserInbox)
            .dispatch(ActivityPubUserInboxJob.self, activityPubRequest)
        
        return HTTPStatus.ok
    }
    
    /// User ActivityPub outbox,
    func outbox(request: Request) async throws -> HTTPStatus {
        request.logger.info("\(request.headers.description)")
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("User outbox activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       httpMethod: .post,
                                                       httpPath: .userOutbox(userName))
        
        try await request
            .queues(.apUserOutbox)
            .dispatch(ActivityPubUserOutboxJob.self, activityPubRequest)

        return HTTPStatus.ok
    }
    
    /// List of users that are followed by the user.
    func following(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request.db, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request.db, sourceId: userId)
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let following = try await followsService.following(on: request.db, sourceId: userId, onlyApproved: true, page: pageInt, size: orderdCollectionSize)
            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems
            
            return try await OrderedCollectionPageDto(id: "\(user.activityPubProfile)/following?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(user.activityPubProfile)/following?page=\(pageInt - 1)" : nil,
                                                      next: showNext ? "\(user.activityPubProfile)/following?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(user.activityPubProfile)/following",
                                                      orderedItems: following.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            return try await OrderedCollectionDto(id: "\(user.activityPubProfile)/following",
                                                  totalItems: totalItems,
                                                  first: showFirst ? "\(user.activityPubProfile)/following?page=1" : nil)
            .encodeResponse(for: request)
        }
    }
    
    /// List of users that follow the user.
    func followers(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request.db, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request.db, targetId: userId)
                
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let follows = try await followsService.follows(on: request.db, targetId: userId, onlyApproved: true, page: pageInt, size: orderdCollectionSize)
            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems

            return try await OrderedCollectionPageDto(id: "\(user.activityPubProfile)/followers?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(user.activityPubProfile)/followers?page=\(pageInt - 1)" :  nil,
                                                      next: showNext ? "\(user.activityPubProfile)/followers?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(user.activityPubProfile)/followers",
                                                      orderedItems: follows.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            return try await OrderedCollectionDto(id: "\(user.activityPubProfile)/followers",
                                                  totalItems: totalItems,
                                                  first: showFirst ? "\(user.activityPubProfile)/followers?page=1" : nil)
            .encodeResponse(for: request)
        }
    }
    
    /// Resource that have been liked by the user.
    func liked(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
    
    /// Returns user ActivityPub profile.
    func status(request: Request) async throws -> NoteDto {
        guard let statusId = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let id = statusId.toId() else {
            throw Abort(.badRequest)
        }

        let statusesService = request.application.services.statusesService
        guard let status = try await statusesService.get(on: request.db, id: id) else {
            throw Abort(.notFound)
        }
        
        guard status.visibility == .public else {
            throw Abort(.forbidden)
        }
        
        guard status.isLocal else {
            throw Abort(.forbidden)
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)

        let noteDto = try NoteDto(id: "\(status.user.activityPubProfile)/statuses/\(status.requireID())",
                                  summary: nil,
                                  inReplyTo: nil,
                                  published: status.createdAt,
                                  url: "\(status.user.activityPubProfile)/statuses/\(status.requireID())",
                                  attributedTo: status.user.activityPubProfile,
                                  to: nil,
                                  cc: nil,
                                  contentWarning: status.contentWarning,
                                  atomUri: nil,
                                  inReplyToAtomUri: nil,
                                  conversation: nil,
                                  content: status.note.html(),
                                  attachment: status.attachments.map({ActivityPubKit.AttachmentDto(mediaType: "image/jpeg",
                                                                                                   url: baseStoragePath.finished(with: "/") + $0.originalFile.fileName,
                                                                                                   name: nil,
                                                                                                   blurhash: $0.blurhash,
                                                                                                   width: $0.originalFile.width,
                                                                                                   height: $0.originalFile.height)}),
                                  tag: nil)
        
        return noteDto
    }
    
    private func getPersonImage(for fileName: String?, on request: Request) -> PersonImageDto? {
        guard let fileName else {
            return nil
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        return PersonImageDto(mediaType: "image/jpeg",
                              url: "\(baseStoragePath)/\(fileName)")
    }
}
