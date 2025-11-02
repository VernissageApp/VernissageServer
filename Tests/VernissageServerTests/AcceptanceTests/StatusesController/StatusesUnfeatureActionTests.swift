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
    
    @Suite("Statuses (POST /statuses/:id/unfeature)", .serialized, .tags(.statuses))
    struct StatusesUnfeatureActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Status should be unfeatured for moderator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maximrojon")
            let user2 = try await application.createUser(userName: "roxyrojon")
            try await application.attach(user: user2, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfeatured", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            _ = try await application.createFeaturedStatus(user: user2, status: statuses.first!)
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "roxyrojon", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unfeature",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.featured == false, "Status should be marked as unfeatured.")
        }
        
        @Test
        func `Status should be unfeatured even if other moderator feature status`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "zibirojon")
            let user2 = try await application.createUser(userName: "zicorojon")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            _ = try await application.createFeaturedStatus(user: user1, status: statuses.first!)
            try await application.attach(user: user2, role: Role.moderator)
            
            // Act.
            _ = try await application.getResponse(
                as: .user(userName: "zicorojon", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unfeature",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            let allFeaturedStatuses = try await application.getAllFeaturedStatuses()
            #expect(allFeaturedStatuses.contains { $0.status.id == statuses.first!.id } == false, "Status wasn't unfeatured.")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinrojon")
            let user2 = try await application.createUser(userName: "adamrojon")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfeatured Forbidden", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            _ = try await application.createFeaturedStatus(user: user2, status: statuses.first!)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adamrojon", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxrojon")
            try await application.attach(user: user1, role: Role.moderator)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxrojon", password: "p@ssword"),
                to: "/statuses/123456789/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquerojon")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfeatured Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unfeature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
