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
    
    @Suite("Statuses (POST /statuses/:id/unreblog)", .serialized, .tags(.statuses))
    struct StatusesUnreblogActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be unreblogged for orginal status")
        func statusShouldBeUnrebloggedForOrginalStatus() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinvox")
            let user2 = try await application.createUser(userName: "adamvox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unreblog", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let createdStatusDto = try await application.getResponse(
                as: .user(userName: "adamvox", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unreblog",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(createdStatusDto.id != nil, "Status wasn't created.")
            #expect(createdStatusDto.reblogged == false, "Status should be marked as not reblogged.")
            #expect(createdStatusDto.reblogsCount == 0, "Reblogged count should be equal 0.")
            
            let notification = try await application.getNotification(type: .reblog, to: user1.requireID(), by: user2.requireID(), statusId: createdStatusDto.id?.toId())
            #expect(notification == nil, "Notification should be deleted.")
        }
        
        @Test("Status should be unreblogged for reblog status")
        func statusShouldBeUnrebloggedForReblogStatus() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "martinvox")
            let user2 = try await application.createUser(userName: "timvox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unreblog Reblog", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            let reblog = try await application.getStatus(reblogId: statuses.first!.requireID())
            
            // Act.
            let createdStatusDto = try await application.getResponse(
                as: .user(userName: "timvox", password: "p@ssword"),
                to: "/statuses/\(reblog!.requireID())/unreblog",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(createdStatusDto.id != nil, "Status wasn't created.")
            #expect(createdStatusDto.reblogged == false, "Status should be marked as not reblogged.")
            #expect(createdStatusDto.reblogsCount == 0, "Reblogged count should be equal 0.")
        }
        
        @Test("Status should return not found for not reblogged status")
        func statusShouldReturnNotFoundForNotRebloggedStatus() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "romanvox")
            _ = try await application.createUser(userName: "georgevox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unreblog Not Found", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "georgevox", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unreblog",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized UUser")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "margotvox")
            let user2 = try await application.createUser(userName: "madamvox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unreblog Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unreblog",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
