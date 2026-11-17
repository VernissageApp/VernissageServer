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
    
    @Suite("ActivityPubShared (POST /shared/inbox [DeleteStatus])", .serialized, .tags(.shared))
    struct ActivityPubSharedDeleteStatusTests {
        var application: Application!
        
        init() async throws {
            self.application = try  await ApplicationManager.shared.application()
        }

        @Test(arguments: ["note", "tombstone", "uri"])
        func `Private Delete accepts supported object forms and repeated delivery preserves one marker`(format: String) async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            _ = try await application.receivePrivateLike(statusActivityPubId: note.id, sender: remote)
            let object = ObjectDto(id: note.id, type: format == "uri" ? nil : (format == "note" ? .note : .tombstone))
            let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                type: .delete, id: note.id + "#delete", actor: .single(ActorDto(id: remote.activityPubProfile)),
                object: .single(object), summary: nil, signature: nil)

            // Act.
            let response = try await application.receiveSignedPrivateActivity(activity, sender: remote)
            _ = try await application.receiveSignedPrivateActivity(activity, sender: remote)
            let messages = try await application.getResponse(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(try #require(status.$directConversation.id))/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.find(status.requireID(), on: application.db) == nil)
            #expect(try await DeletedDirectMessage.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 1)
            #expect(try await DirectMessageLikeReceipt.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .count() == 0)
            #expect(messages.total == 1)
            #expect(messages.data.first?.status == nil)
            #expect(messages.data.first?.deletedAt != nil)
        }

        @Test(arguments: [false, true])
        func `Private Delete cannot be forged by another actor or an invalid signature`(invalidSignature: Bool) async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let stranger = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let actor = invalidSignature ? remote : stranger
            let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                type: .delete, id: note.id + "#delete", actor: .single(ActorDto(id: actor.activityPubProfile)),
                object: .single(ObjectDto(id: note.id, type: .tombstone)), summary: nil, signature: nil)

            // Act.
            _ = try await application.receiveSignedPrivateActivity(activity, sender: actor, invalidSignature: invalidSignature)

            // Assert.
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 1)
            #expect(try await DeletedDirectMessage.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }
        
        @Test
        func `Authenticated remote Delete leaves a marker in a direct conversation`() async throws {
            // Arrange.
            let sender = try await application.createRemoteDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let request = Request(application: application, on: application.eventLoopGroup.next())
            let status = Status(id: application.services.snowflakeService.generate(), isLocal: false,
                userId: try sender.requireID(), note: "Incoming private message", baseAddress: "http://localhost:8080",
                userName: sender.userName, application: nil, categoryId: nil, visibility: .mentioned, publishedAt: Date())
            let stored = try await application.services.activityPubDirectMessagesService.store(status: status,
                recipientIds: [recipient.requireID()], conversationId: nil, on: request.executionContext)
            let conversationId = try #require(stored.$directConversation.id)
            let reply = try await application.sendDirectMessage(
                author: recipient,
                recipients: [sender],
                conversationId: String(conversationId),
                replyToStatusId: String(try stored.requireID()))

            let target = ActivityPub.Notes.delete(sender.activityPubProfile, stored.activityPubId, try #require(sender.privateKey),
                "/shared/inbox", Constants.userAgent, "localhost", [recipient.activityPubProfile])

            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: target.headers?.getHTTPHeaders() ?? .init(),
                body: try #require(target.httpBody))

            let messages = try await application.getResponse(
                as: .user(userName: recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.find(stored.requireID(), on: application.db) == nil)
            #expect(messages.total == 2)
            #expect(messages.data.first?.id == reply.id)
            #expect(messages.data.last?.id == status.stringId())
            #expect(messages.data.last?.deletedAt != nil)
            #expect(messages.data.last?.status == nil)
        }

        @Test
        func `Status should be deleted when all correct data has been applied`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikidavin", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
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
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase == nil, "Status must be deleted from local datbase.")
        }
        
        @Test
        func `Status should not be deleted when status is local`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markdavin", generateKeys: true, isLocal: true)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
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
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase != nil, "Status must not be deleted from local datbase.")
        }
        
        @Test
        func `Delete status should fail when date is outside time frame`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marcindavin", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
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
            
            var headers = deleteTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase != nil, "Status must not be deleted from local datbase.")
        }

        @Test
        func `Status should not be deleted when activity actor is not status owner`() async throws {
            // Arrange.
            let owner = try await application.createUser(userName: "statusownerdelete", generateKeys: true, isLocal: false)
            let attacker = try await application.createUser(userName: "statusattackerdelete", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: owner)
            let status = try await application.createStatus(user: owner, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }

            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)

            let deleteTarget = ActivityPub.Notes.delete(attacker.activityPubProfile,
                                                        status.activityPubId,
                                                        attacker.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase != nil, "Status must not be deleted when actor is not status owner.")
        }
    }
}
