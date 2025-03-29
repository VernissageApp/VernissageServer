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
    
    @Suite("Statuses (POST /statuses/:id/feature)", .serialized, .tags(.statuses))
    struct StatusesFeatureActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be featured for moderator")
        func statusShouldBeFeaturedForModerator() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roxyfokimo")
            let user2 = try await application.createUser(userName: "tobyfokimo")
            try await application.attach(user: user2, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Featured", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "tobyfokimo", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/feature",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.featured == true, "Status should be marked as featured.")
        }
        
        @Test("Status should be featured only once")
        func statusShouldBeFeaturedOnlyOnce() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "zibifokimo")
            let user2 = try await application.createUser(userName: "zicofokimo")
            try await application.attach(user: user1, role: Role.moderator)
            try await application.attach(user: user2, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Featured", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.createFeaturedStatus(user: user1, status: statuses.first!)
            
            // Act.
            _ = try await application.getResponse(
                as: .user(userName: "zicofokimo", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/feature",
                method: .POST,
                decodeTo: StatusDto.self
            )
                        
            // Assert.
            let allFeaturedStatuses = try await application.getAllFeaturedStatuses()
            #expect(allFeaturedStatuses.count { $0.status.id == statuses.first!.id } == 1, "Status wasn't featured once.")
        }
        
        @Test("Status should be mark as featured even if other moderator featured status")
        func statusShouldBeFeaturedEvenIfOtherModeratorFeaturedStatus() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "andyfokimo")
            let user2 = try await application.createUser(userName: "arrinfokimo")
            try await application.attach(user: user1, role: Role.moderator)
            try await application.attach(user: user2, role: Role.moderator)
            
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Featured", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.createFeaturedStatus(user: user1, status: statuses.first!)
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "arrinfokimo", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())",
                method: .GET,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't returned.")
            #expect(statusDto.featured == true, "Status should be marked as featured.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinefokimo")
            _ = try await application.createUser(userName: "adamefokimo")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Featured Forbidden", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adamefokimo", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/feature",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned for status with mentioned visibility")
        func notFoundShouldBeReturnedForStatusWithMentionedVisibility() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brosefokimo")
            let user2 = try await application.createUser(userName: "ingaefokimo")
            try await application.attach(user: user2, role: Role.moderator)
            
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "ingaefokimo", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/feature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxefokimo")
            try await application.attach(user: user1, role: Role.moderator)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxefokimo", password: "p@ssword"),
                to: "/statuses/123456789/feature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiqueefokimo")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Featured Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/feature",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
