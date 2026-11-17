//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [Unfavourite])", .serialized, .tags(.shared))
    struct ActivityPubSharedUnfavouriteStatusTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test(arguments: [false, true])
        func `Private Undo removes only its own Like and notification`(referenceOnly: Bool) async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let other = try await application.createRemoteDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [remote, other])

            let objectId = try #require(message.status?.activityPubId)
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote)
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: other)

            // Act.
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote,
                undo: true, embeddedActorId: other.activityPubProfile)
            let before = try await Status.find(try requireDirectMessageId(message.id), on: application.db)?.favouritesCount
            let response = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote,
                undo: true, referenceOnly: referenceOnly)
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote,
                undo: true, referenceOnly: referenceOnly)

            // Assert.
            #expect(before == 2)
            #expect(response.status == .ok)
            #expect(try await Status.find(requireDirectMessageId(message.id), on: application.db)?.favouritesCount == 1)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$user.$id == remote.requireID())
                .count() == 0)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$user.$id == other.requireID())
                .count() == 1)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$notificationType == .favourite)
                .filter(\.$byUser.$id == remote.requireID())
                .count() == 0)
        }

        @Test
        func `Delayed Undo of an older Like leaves a new Like intact`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [remote])

            let objectId = try #require(message.status?.activityPubId)
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote, favouriteId: "old")
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote, favouriteId: "old", undo: true)
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote, favouriteId: "new")

            // Act.
            let response = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote, favouriteId: "old", undo: true)
            let stored = try #require(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$user.$id == remote.requireID())
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(stored.activityPubId == remote.activityPubProfile + "#likes/new")
            #expect(try await Status.find(requireDirectMessageId(message.id), on: application.db)?.favouritesCount == 1)
        }

        @Test(arguments: [false, true])
        func `A replayed Like after Undo and a Like arriving after its Undo stay undone`(undoArrivesFirst: Bool) async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [remote])

            let objectId = try #require(message.status?.activityPubId)

            if undoArrivesFirst == false {
                _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote)
            }

            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote, undo: true)

            // Act.
            _ = try await application.receivePrivateLike(statusActivityPubId: objectId, sender: remote)

            // Assert.
            #expect(try await Status.find(requireDirectMessageId(message.id), on: application.db)?.favouritesCount == 0)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .count() == 0)
            let receipt = try #require(try await DirectMessageLikeReceipt.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .first())
            #expect(receipt.isUndone)
        }
        
        @Test
        func `Status should be unfavourited when all correct data has been applied`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikitebox", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            _ = try await application.createStatusFavourite(statusId: createdStatus!.requireID(), userId: user.requireID())
            
            let unlikeTarget = ActivityPub.Notes.unlike("3412324",
                                                        user.activityPubProfile,
                                                        status.activityPubId,
                                                        user.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: unlikeTarget.headers?.getHTTPHeaders() ?? .init(),
                body: unlikeTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase == nil, "Status must be unfavourited in local datbase.")
        }
        
        @Test
        func `Status should not be unfavourited when date is outside time frame`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marcintebox", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            _ = try await application.createStatusFavourite(statusId: createdStatus!.requireID(), userId: user.requireID())
            
            let unlikeTarget = ActivityPub.Notes.unlike("3412324",
                                                        user.activityPubProfile,
                                                        status.activityPubId,
                                                        user.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = unlikeTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: unlikeTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase != nil, "Status must not be unfavourited in local datbase.")
        }
    }
}
