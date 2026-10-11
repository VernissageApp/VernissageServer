//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Statuses (PUT /statuses/:id)", .serialized, .tags(.statuses))
    struct StatusesUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Direct messages cannot be edited through the status API`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [recipient],
                note: "Original private message")

            let dto = StatusRequestDto(note: "Edited private message", visibility: .mentioned, sensitive: false,
                contentWarning: nil, commentsDisabled: false, categoryId: nil, replyToStatusId: nil, attachmentIds: [])

            // Act.
            let response = try await application.getErrorResponse(as: .user(userName: author.userName, password: "p@ssword"),
                to: "/statuses/\(message.id)", method: .PUT, data: dto)
            let status = try #require(try await Status.find(requireDirectMessageId(message.id), on: application.db))

            // Assert.
            #expect(response.status == .forbidden)
            #expect(response.error.code == DirectMessageError.unsupportedStatusOperation.code)
            #expect(status.note == "Original private message")
            #expect(status.updatedByUserAt == nil)
        }

        @Test
        func `Status should be updated by authorized user`() async throws {
            
            // Arrange.
            let categorySport = try await application.getCategory(name: "Sport")
            let categoryStreet = try await application.getCategory(name: "Street")

            let user = try await application.createUser(userName: "robinurlich")
            let (statuses, attachments) = try await application.createStatuses(user: user,
                                                                               notePrefix: "Local timeline #football and @adam@localhost.com",
                                                                               categoryId: categoryStreet?.stringId(),
                                                                               amount: 1)

            let attachment = try await application.createAttachment(user: user,
                                                                    description: "This is name",
                                                                    blurhash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
                                                                    make: "Sony",
                                                                    model: "A7IV",
                                                                    lens: "Sigma",
                                                                    createDate: "2025-01-10T10:10:01Z",
                                                                    focalLenIn35mmFilm: "85",
                                                                    fNumber: "1.8",
                                                                    exposureTime: "10",
                                                                    photographicSensitivity: "100",
                                                                    film: "Kodak",
                                                                    latitude: "50.01N",
                                                                    longitude: "18.0E",
                                                                    flash: "Yes",
                                                                    focalLength: "120"
            )

            defer {
                application.clearFiles(attachments: attachments)
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is #street new content @gigifoter@localhost.com",
                                                    visibility: .public,
                                                    sensitive: true,
                                                    contentWarning: "Content warning",
                                                    commentsDisabled: false,
                                                    categoryId: categorySport?.stringId(),
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let updatedStatusDto = try await application.getResponse(
                as: .user(userName: "robinurlich", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .PUT,
                data: statusRequestDto,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(updatedStatusDto.id != nil, "Status wasn't created.")
            #expect(statusRequestDto.note == updatedStatusDto.note, "Status note should be correct.")
            #expect(statusRequestDto.visibility == updatedStatusDto.visibility, "Status visibility should be correct.")
            #expect(statusRequestDto.sensitive == updatedStatusDto.sensitive, "Status sensitive should be correct.")
            #expect(statusRequestDto.contentWarning == updatedStatusDto.contentWarning, "Status contentWarning should be correct.")
            #expect(statusRequestDto.commentsDisabled == updatedStatusDto.commentsDisabled, "Status commentsDisabled should be correct.")
            #expect(statusRequestDto.replyToStatusId == updatedStatusDto.replyToStatusId, "Status replyToStatusId should be correct.")
            #expect(updatedStatusDto.user.userName == "robinurlich", "User should be returned.")
            #expect(updatedStatusDto.category?.name == "Sport", "Category should be correct.")
            #expect(updatedStatusDto.publishedAt != nil, "Published at date should be set.")
            
            let statusAfterUpdate = try await application.services.statusesService.get(id: statuses.first!.requireID(), on: application.db)!
            #expect(statusAfterUpdate.note == "This is #street new content @gigifoter@localhost.com", "Note should be saved in updated status.")
            #expect(statusAfterUpdate.sensitive == true, "Sensitive should be saved in updated status.")
            #expect(statusAfterUpdate.contentWarning == "Content warning", "Content warning should be saved in updated status.")
            #expect(statusAfterUpdate.category?.name == "Sport", "Category should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.count == 1, "New attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.blurhash == "LEHV6nWB2yk8pyo0adR*.7kCMdnj", "Blurhash of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.description == "This is name", "Description of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.originalFile.width == 1706, "Width of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.originalFile.height == 882, "Height of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.make == "Sony", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.model == "A7IV", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.lens == "Sigma", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.createDate == "2025-01-10T10:10:01Z", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.focalLenIn35mmFilm == "85", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.fNumber == "1.8", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.exposureTime == "10", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.photographicSensitivity == "100", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.film == "Kodak", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.latitude == "50.01N", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.longitude == "18.0E", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.flash == "Yes", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.attachments.first?.exif?.focalLength == "120", "Exif make of new attachment should be saved in updated status.")
            #expect(statusAfterUpdate.hashtags.contains(where: { $0.hashtag == "street" }) == true, "Hashtag should be saved in updated status.")
            #expect(statusAfterUpdate.mentions.contains(where: { $0.userName == "gigifoter@localhost.com" }) == true, "Mention should be saved in updated status.")
            
            let statusHistoryFromDatabase = try await application.getStatusHistory(statusId: statusAfterUpdate.requireID())
            #expect(statusHistoryFromDatabase != nil, "Status history should be saved.")
            
            let statusHistory = statusHistoryFromDatabase!
            #expect(statusHistory.note == "Local timeline #football and @adam@localhost.com 1", "Note should be saved in updated status.")
            #expect(statusHistory.sensitive == false, "Sensitive should be saved in history status.")
            #expect(statusHistory.contentWarning == nil, "Content warning should be saved in history status.")
            #expect(statusHistory.category?.name == "Street", "Category should be saved in history status.")
            #expect(statusHistory.attachments.count == 1, "New attachment should be saved in hisotory status.")
            #expect(statusHistory.attachments.first?.blurhash == "BLURHASH", "Blurhash of new attachment should be saved in history status.")
            #expect(statusHistory.attachments.first?.description == "This is description...", "Description of new attachment should be saved in history status.")
            #expect(statusHistory.attachments.first?.exif?.make == "Sony", "Exif make of new attachment should be saved in history status.")
            #expect(statusHistory.attachments.first?.exif?.model == "A7IV", "Exif make of new attachment should be saved in history status.")
            #expect(statusHistory.attachments.first?.exif?.lens == "Viltrox 85", "Exif make of new attachment should be saved in history status.")
            #expect(statusHistory.attachments.first?.exif?.createDate == "2023-07-13T20:15:35.319+02:00", "Exif make of new attachment should be saved in history status.")
            #expect(statusHistory.hashtags.contains(where: { $0.hashtag == "football" }) == true, "Hashtag should be saved in history status.")
            #expect(statusHistory.mentions.contains(where: { $0.userName == "adam@localhost.com" }) == true, "Mention should be saved in history status.")
        }
        
        @Test
        func `Status should not be updated when limit of attachments is reached`() async throws {
            
            // Arrange.
            let categorySport = try await application.getCategory(name: "Sport")
            let categoryStreet = try await application.getCategory(name: "Street")

            let user = try await application.createUser(userName: "yorkurlich")
            let (statuses, attachments) = try await application.createStatuses(user: user,
                                                                               notePrefix: "Local timeline #football and @adam@localhost.com",
                                                                               categoryId: categoryStreet?.stringId(),
                                                                               amount: 1)

            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            let attachment3 = try await application.createAttachment(user: user)
            let attachment4 = try await application.createAttachment(user: user)
            let attachment5 = try await application.createAttachment(user: user)
            
            defer {
                application.clearFiles(attachments: attachments)
                application.clearFiles(attachments: [attachment1, attachment2, attachment3, attachment4, attachment5])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is #street new content @gigifoter@localhost.com",
                                                    visibility: .public,
                                                    sensitive: true,
                                                    contentWarning: "Content warning",
                                                    commentsDisabled: false,
                                                    categoryId: categorySport?.stringId(),
                                                    replyToStatusId: nil,
                                                    attachmentIds: [
                                                        attachment1.stringId()!,
                                                        attachment2.stringId()!,
                                                        attachment3.stringId()!,
                                                        attachment4.stringId()!,
                                                        attachment5.stringId()!
                                                    ])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "yorkurlich", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .PUT,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Status should not be updated for unauthorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "chrisurlich")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/statuses/1",
                method: .PUT,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Status should not be updated when status created by someone else`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carolineurlich")
            let user2 = try await application.createUser(userName: "olaurlich")
            
            let (statuses, attachments) = try await application.createStatuses(user: user1,
                                                                               notePrefix: "Test note",
                                                                               amount: 1)
            
            let attachment = try await application.createAttachment(user: user2)
            defer {
                application.clearFiles(attachments: attachments)
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "olaurlich", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .PUT,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Status should not be updated for attachments created by someone else`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "trendurlich")
            let user2 = try await application.createUser(userName: "ronaldurlich")
            
            let (statuses, attachments) = try await application.createStatuses(user: user1,
                                                                               notePrefix: "Test note",
                                                                               amount: 1)
            
            let attachment = try await application.createAttachment(user: user2)
            defer {
                application.clearFiles(attachments: attachments)
                application.clearFiles(attachments: [attachment])
            }
            
            let statusRequestDto = StatusRequestDto(note: "This is note...",
                                                    visibility: .followers,
                                                    sensitive: false,
                                                    contentWarning: nil,
                                                    commentsDisabled: false,
                                                    replyToStatusId: nil,
                                                    attachmentIds: [attachment.stringId()!])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "trendurlich", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .PUT,
                data: statusRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }

        @Test(arguments: [false, true])
        func `Mentioned visibility requires the direct messages endpoint`(hasAttachment: Bool) async throws {
            // Arrange.
            let user = try await application.createDirectMessageUser()
            let status = try await application.createStatus(user: user, note: "Original")
            let attachment = try await application.createAttachment(user: user)

            defer { application.clearFiles(attachments: [attachment]) }
            let dto = StatusRequestDto(note: "Private message", visibility: .mentioned, sensitive: false,
                                       contentWarning: nil, commentsDisabled: false, categoryId: nil,
                                       replyToStatusId: nil, attachmentIds: hasAttachment ? [attachment.stringId()!] : [])

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())", method: .PUT, data: dto)

            // Assert.
            #expect(response.status == .badRequest)
            #expect(response.error.code == StatusError.directMessagesRequireDedicatedEndpoint.code)
            #expect(response.error.reason.contains("/api/v1/direct-messages"))
            let unchanged = try #require(try await Status.find(status.id, on: application.db))
            #expect(unchanged.visibility == .public)
            #expect(unchanged.note == "Original")
            #expect(unchanged.$replyToStatus.id == nil)
            #expect(try await StatusHistory.query(on: application.db)
                .filter(\.$orginalStatus.$id == status.requireID())
                .count() == 0)
            let unused = try #require(try await Attachment.find(attachment.id, on: application.db))
            #expect(unused.$status.id == nil)
        }

        @Test(arguments: [StatusVisibilityDto.public, .quietPublic, .followers], [false, true])
        func `Direct message parent requires the direct messages reply endpoint`(visibility: StatusVisibilityDto, hasAttachment: Bool) async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let user = fixture.author
            let status = try await application.createStatus(user: user, note: "Original")
            let attachment = try await application.createAttachment(user: user)

            defer { application.clearFiles(attachments: [attachment]) }
            let dto = StatusRequestDto(note: "Reply", visibility: visibility, sensitive: false,
                                       contentWarning: nil, commentsDisabled: false, categoryId: nil,
                                       replyToStatusId: fixture.message.id,
                                       attachmentIds: hasAttachment ? [attachment.stringId()!] : [])
            let initialCount = try await Status.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .count()

            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())", method: .PUT, data: dto)

            // Assert.
            #expect(response.status == .badRequest)
            #expect(response.error.code == StatusError.directMessagesRequireDedicatedEndpoint.code)
            #expect(try await Status.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .count() == initialCount)
            let unchanged = try #require(try await Status.find(status.id, on: application.db))
            #expect(unchanged.visibility == .public)
            #expect(unchanged.note == "Original")
            #expect(unchanged.$replyToStatus.id == nil)
            #expect(try await StatusHistory.query(on: application.db)
                .filter(\.$orginalStatus.$id == status.requireID())
                .count() == 0)
            let unused = try #require(try await Attachment.find(attachment.id, on: application.db))
            #expect(unused.$status.id == nil)
        }
    }
}
