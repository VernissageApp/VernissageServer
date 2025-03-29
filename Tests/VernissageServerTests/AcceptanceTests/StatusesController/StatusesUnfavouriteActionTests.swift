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
    
    @Suite("Statuses (POST /statuses/:id/unfavourite)", .serialized, .tags(.statuses))
    struct StatusesUnfavouriteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be unfavourited for authorized user")
        func statusShouldBeUnfavouritedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinmina")
            let user2 = try await application.createUser(userName: "adammina")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses.first!)
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adammina", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unfavourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == false, "Status should be marked as unfavourited.")
            #expect(statusDto.favouritesCount == 0, "Favourited count should be equal 0.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statusDto.id?.toId())
            #expect(notification == nil, "Notification should be deleted.")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxmina")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxmina", password: "p@ssword"),
                to: "/statuses/123456789/unfavourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquemina")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unfavourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
