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
import Queues

extension ControllersTests {
    
    @Suite("Statuses (DELETE /statuses/:id)", .serialized, .tags(.statuses))
    struct StatusesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Federated private Delete reaches only the original audience and continues past a failed inbox`() async throws {
            // Arrange.
            let author = try await application.createUser(userName: "dmdelete" + UUID().uuidString, generateKeys: true)
            let local = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser(isLocal: false)
            let second = try await application.createDirectMessageUser(isLocal: false)
            let newcomer = try await application.createDirectMessageUser(isLocal: false)
            _ = try await application.createFollow(sourceId: newcomer.requireID(), targetId: author.requireID(), approved: true)
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [first, second, local],
                note: "Secret content")

            _ = try await application.sendDirectMessage(
                author: author,
                recipients: [newcomer],
                conversationId: message.conversationId,
                replyToStatusId: message.id)

            let session = DirectMessageDeliveryURLProtocol.session(failOnce: [try #require(first.userInbox)])

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }
            let payload = StatusDeleteJobDto(userId: try author.requireID(), statusId: try requireDirectMessageId(message.id),
                                             activityPubStatusId: try #require(message.status?.activityPubId))
            let context = application.getQueueContext(queueName: .statusDeleter)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: author.userName, password: "p@ssword"),
                to: "/statuses/\(message.id)",
                method: .DELETE)

            await #expect(throws: Abort.self) { try await StatusDeleterJob().dequeue(context, payload) }
            let firstAttempt = DirectMessageDeliveryURLProtocol.requests

            try await StatusDeleterJob().dequeue(context, payload)
            let allRequests = DirectMessageDeliveryURLProtocol.requests

            // Assert.
            #expect(response.status == .ok)
            #expect(firstAttempt.count == 2)
            #expect(Set(firstAttempt.compactMap { $0.url?.absoluteString }) == Set([try #require(first.userInbox), try #require(second.userInbox)]))
            #expect(allRequests.count == 4)
            #expect(try await DeletedDirectMessageRecipient.query(on: application.db)
                .filter(\.$message.$id == payload.statusId)
                .count() == 3)

            for request in allRequests {
                let body = try #require(request.httpBody)
                let activity = try JSONDecoder().decode(ActivityDto.self, from: body)
                #expect(activity.type == .delete)
                #expect(activity.actor.actorIds() == [author.activityPubProfile])
                #expect(Set(activity.to?.actorIds() ?? []) == Set([first.activityPubProfile, second.activityPubProfile, local.activityPubProfile]))
                #expect(activity.object.objects().first?.id == payload.activityPubStatusId)
                #expect(request.value(forHTTPHeaderField: "Signature")?.contains(author.activityPubProfile + "#main-key") == true)
                #expect(String(decoding: body, as: UTF8.self).contains("Secret content") == false)
                #expect(String(decoding: body, as: UTF8.self).contains("activitystreams#Public") == false)
            }
        }
        
        @Test
        func `Deleting a direct message with an attachment removes content and schedules file cleanup`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let attachment = try await application.createAttachment(user: author)

            defer { application.clearFiles(attachments: [attachment]) }
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [recipient],
                note: "Private image",
                attachmentIds: [try #require(attachment.stringId())])

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: author.userName, password: "p@ssword"),
                to: "/statuses/\(message.id)",
                method: .DELETE)

            let detached = try #require(try await Attachment.find(attachment.requireID(), on: application.db))
            let history = try await application.getResponse(
                as: .user(userName: recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let favourite = try await application.sendRequest(
                as: .user(userName: recipient.userName, password: "p@ssword"),
                to: "/statuses/\(message.id)/favourite",
                method: .POST)

            // Assert.
            #expect(response.status == .ok)
            #expect(detached.$status.id == nil)
            #expect(history.data.first?.status == nil)
            #expect(history.data.first?.deletedAt != nil)
            #expect(favourite.status == .notFound)
        }

        @Test
        func `Deleting a direct root preserves replies and a content free marker`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let firstReply = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.author],
                note: "First branch",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let secondReply = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Second branch",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let id = try requireDirectMessageId(fixture.message.id)
            let conversationId = try requireDirectMessageId(fixture.message.conversationId)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .DELETE)

            let messages = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let root = try #require(messages.data.first { $0.id == fixture.message.id })
            let reply = try #require(try await Status.find(try requireDirectMessageId(firstReply.id), on: application.db))

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.find(id, on: application.db) == nil)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == id)
                .count() == 0)
            #expect(messages.total == 3)
            #expect(messages.data.map(\.id) == [secondReply.id, firstReply.id, fixture.message.id])
            #expect(root.status == nil)
            #expect(root.deletedAt != nil)
            #expect(root.author?.id == fixture.author.stringId())
            #expect(root.publishedAt != nil)
            #expect(root.recipients.map(\.id) == [fixture.recipient.stringId()])
            #expect(reply.$replyToStatus.id == nil)
            #expect(reply.replyToActivityPubId == fixture.message.status?.activityPubId)
            #expect(messages.data.first { $0.id == firstReply.id }?.replyToStatusId == fixture.message.id)
            #expect(try await DirectConversation.find(conversationId, on: application.db)?.$rootStatus.id == nil)
        }

        @Test
        func `Deleting the last direct message clears previews and unread state without moving conversations`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let id = try requireDirectMessageId(fixture.message.id)
            let conversationId = try requireDirectMessageId(fixture.message.conversationId)
            let before = try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .all()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .DELETE)

            let conversation = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            let after = try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .all()

            // Assert.
            #expect(response.status == .ok)
            #expect(conversation.summary == nil)
            #expect(conversation.lastStatusId == fixture.message.id)
            #expect(conversation.lastMessageDeletedAt != nil)
            #expect(conversation.hasUnreadMessages == false)
            #expect(conversation.participants.count == 2)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == id)
                .count() == 0)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == id)
                .count() == 0)

            for inbox in after {
                let previous = try #require(before.first { $0.id == inbox.id })
                #expect(inbox.lastActivityAt == previous.lastActivityAt)
                #expect(inbox.lastReadAt == previous.lastReadAt)
                #expect(inbox.isMuted == previous.isMuted)
                #expect(inbox.summary == nil)
            }
        }

        @Test
        func `Only original recipients can see a deleted message in a shared conversation`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let limited = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                note: "Private subset",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(limited.id)",
                method: .DELETE)

            let originalAuthor = try await application.getResponse(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let addressed = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(originalAuthor.data.map(\.id) == [fixture.message.id])
            #expect(addressed.data.map(\.id) == [limited.id])
            #expect(addressed.data.first?.deletedAt != nil)
            #expect(addressed.data.first?.status == nil)
        }

        @Test
        func `Recipient cannot delete someone elses direct message`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let id = try requireDirectMessageId(fixture.message.id)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .DELETE)

            // Assert.
            #expect(response.status == .forbidden)
            #expect(try await Status.find(id, on: application.db) != nil)
            #expect(try await DeletedDirectMessage.find(id, on: application.db) == nil)
        }

        @Test
        func `Status should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinworth")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Deleted", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robinworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }

        @Test
        func `Status delete should remove timeline markers`() async throws {
            // Arrange.
            let statusOwner = try await application.createUser(userName: "timelinemarkerowner")
            let markerOwner = try await application.createUser(userName: "timelinemarkerreader")
            let (statuses, attachments) = try await application.createStatuses(
                user: statusOwner,
                notePrefix: "Timeline marker status",
                amount: 1
            )
            defer {
                application.clearFiles(attachments: attachments)
            }

            let status = try #require(statuses.first)
            let marker = try await application.createTimelineMarker(user: markerOwner, status: status, timeline: .local)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "timelinemarkerowner", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let markerFromDatabase = try await TimelineMarker.query(on: application.db)
                .filter(\.$id == marker.requireID())
                .first()
            #expect(markerFromDatabase == nil, "Timeline marker should be deleted together with status.")
        }
        
        @Test
        func `Status should be deleted by administrator`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "adamworth")
            
            let administrator = try await application.createUser(userName: "tobiaszworth")
            try await application.attach(user: administrator, role: Role.administrator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Delete Administrator", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "tobiaszworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }
        
        @Test
        func `Status should be deleted by moderator`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "romanekworth")
            
            let moderator = try await application.createUser(userName: "karolzworth")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Deleted Moderator", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "karolzworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
        }
        
        @Test
        func `Status and his reblogs should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinworth")
            let user2 = try await application.createUser(userName: "gorgiworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Deleted Reblogs", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let reblog = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "carinworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
            
            let reblogStatusFromDatabase = try? await application.getStatus(id: reblog.requireID())
            #expect(reblogStatusFromDatabase == nil, "Reblog status should be deleted.")
        }
        
        @Test
        func `Status and his replies should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxworth")
            let user2 = try await application.createUser(userName: "benworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Delete Replies", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let status2A = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            let status2B = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            let status3A = try await application.replyStatus(user: user2, comment: "This is reply for status 2A", status: status2A)
            let status3B = try await application.replyStatus(user: user2, comment: "This is reply for status 2B", status: status2B)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "maxworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
            
            let status2AFromDatabase = try? await application.getStatus(id: status2A.requireID())
            #expect(status2AFromDatabase == nil, "Reply status2A status should be deleted.")
            
            let status2BFromDatabase = try? await application.getStatus(id: status2B.requireID())
            #expect(status2BFromDatabase == nil, "Reply status2B status should be deleted.")
            
            let status3AFromDatabase = try? await application.getStatus(id: status3A.requireID())
            #expect(status3AFromDatabase == nil, "Reply status3A status should be deleted.")
            
            let status3BFromDatabase = try? await application.getStatus(id: status3B.requireID())
            #expect(status3BFromDatabase == nil, "Reply status3B status should be deleted.")
        }
        
        @Test
        func `Status and his hashtags should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "richardworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note #photo #blackandwhite", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "richardworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
        }
        
        @Test
        func `Status and his mentions should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "marecworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note @marcin @kamila", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "marecworth", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
        }
        
        @Test
        func `Status and his history should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rubyworth")

            let attachment1 = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note @marcin #street", attachmentIds: [attachment1.stringId()!], visibility: .public)
            let attachemnt2 = try await application.updateStatus(statusId: status.requireID(), user: user, note: "This is first update")
            
            defer {
                application.clearFiles(attachments: [attachment1, attachemnt2])
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "rubyworth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase == nil, "Orginal status should be deleted.")
        }
        
        @Test
        func `Status and his evetns should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brian1worth")
            let user2 = try await application.createUser(userName: "brian2worth")
            let user3 = try await application.createUser(userName: "brian3worth")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user2.requireID(), type: .announce)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user3.requireID(), type: .announce)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "brian1worth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let statusFromDatabase = try? await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase == nil, "Status should be deleted.")
            
            let statusActivityPubEvents = try await application.getStatusActivityPubEvents(statusId: status.requireID())
            #expect(statusActivityPubEvents.count == 0, "Status ActivityPub events should be deleted")
        }
        
        @Test
        func `Reply count should be recalculated when deleting comment`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "ninaworth")
            let user2 = try await application.createUser(userName: "anielkaworth")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Delete Replies", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "anielkaworth", password: "p@ssword"),
                to: "/statuses/\(comment.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let parentStatus = try? await application.getStatus(id: statuses.first!.requireID())
            #expect(parentStatus?.repliesCount == 0, "Replies count should be recalculated.")
        }
        
        @Test
        func `Status delete should remove notifications referenced by main status id`() async throws {
            // Arrange.
            let statusOwner = try await application.createUser(userName: "notifownerworth")
            let notificationAuthor = try await application.createUser(userName: "notifauthorworth")
            let attachment = try await application.createAttachment(user: statusOwner)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let status = try await application.createStatus(
                user: statusOwner,
                note: "Status for notification mainStatus reference delete",
                attachmentIds: [attachment.stringId()!],
                visibility: .public
            )
            
            let notificationId = await ApplicationManager.shared.generateId()
            let notification = Notification(
                id: notificationId,
                notificationType: .update,
                to: try statusOwner.requireID(),
                by: try notificationAuthor.requireID(),
                statusId: nil,
                mainStatusId: try status.requireID()
            )
            try await notification.save(on: application.db)
            _ = try await application.createNotificationMarker(user: statusOwner, notification: notification)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "notifownerworth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let notificationFromDatabase = try await Notification.query(on: application.db)
                .filter(\.$id == notificationId)
                .first()
            #expect(notificationFromDatabase == nil, "Notification referenced by mainStatusId should be deleted.")
            
            let markerFromDatabase = try await NotificationMarker.query(on: application.db)
                .filter(\.$notification.$id == notificationId)
                .first()
            #expect(markerFromDatabase == nil, "Notification marker should be deleted together with notification.")
        }
        
        @Test
        func `Status delete should remove reports referenced by main status id`() async throws {
            // Arrange.
            let statusOwner = try await application.createUser(userName: "reportownerworth")
            let reporter = try await application.createUser(userName: "reporterworth")
            let attachment = try await application.createAttachment(user: statusOwner)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let status = try await application.createStatus(
                user: statusOwner,
                note: "Status for report mainStatus reference delete",
                attachmentIds: [attachment.stringId()!],
                visibility: .public
            )
            
            let reportId = await ApplicationManager.shared.generateId()
            let report = Report(
                id: reportId,
                userId: try reporter.requireID(),
                reportedUserId: try statusOwner.requireID(),
                statusId: nil,
                mainStatusId: try status.requireID(),
                comment: "Report with only mainStatus reference",
                forward: false,
                category: nil,
                ruleIds: nil
            )
            try await report.save(on: application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "reportownerworth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let reportFromDatabase = try await Report.query(on: application.db)
                .filter(\.$id == reportId)
                .first()
            #expect(reportFromDatabase == nil, "Report referenced by mainStatusId should be deleted.")
        }
        
        @Test
        func `Status should not be deleted for unauthorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "erikworth")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Status should not be deleted for status created by other user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maciasworth")
            let user = try await application.createUser(userName: "georgeworth")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "maciasworth", password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
    }
}
