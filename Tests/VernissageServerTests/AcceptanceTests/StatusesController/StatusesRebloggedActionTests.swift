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
    
    @Suite("Statuses (GET /statuses/:id/reblogged)", .serialized, .tags(.statuses))
    struct StatusesRebloggedActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Reblogged users of boosted status should be users boosting original`() async throws {
            // Arrange.
            let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let owner = try await application.createUser(userName: "bo" + suffix)
            let booster = try await application.createUser(userName: "bb" + suffix)
            let actor = try await application.createUser(userName: "ba" + suffix)
            let original = try await application.createStatus(user: owner, note: "Original photo")
            let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())
            _ = try await application.createStatus(user: actor, note: nil, reblogId: original.requireID())

            // Act.
            let response = try await application.getResponse(
                as: .user(userName: actor.userName, password: "p@ssword"),
                to: "/statuses/\(boost.requireID())/reblogged",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )

            // Assert.
            let expectedIds = [try booster.requireID(), try actor.requireID()].map(String.init)
            #expect(Set(response.data.compactMap(\.id)) == Set(expectedIds))
        }

        @Test
        func `List of reblogged users should be returned for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinjorgi")
            let user2 = try await application.createUser(userName: "adamjorgi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Reblogged", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let reblogged = try await application.getResponse(
                as: .user(userName: "carinjorgi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/reblogged",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(reblogged.data.count == 1, "All followers should be returned.")
        }
        
        @Test
        func `List of reblogged users should be returned for not authorized user and public status`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "peterjorgi")
            let user2 = try await application.createUser(userName: "michaeljorgi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let reblogged = try await application.getResponse(
                to: "/statuses/\(statuses.first!.requireID())/reblogged",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(reblogged.data.count == 1, "All followers should be returned.")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user and not public status`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moniquejorgi")
            let user2 = try await application.createUser(userName: "vorixjorgi")
            
            let attachment = try await application.createAttachment(user: user1)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!])
            _ = try await application.reblogStatus(user: user2, status: status)
            try await application.changeStatusVisibility(statusId: status.requireID(), visibility: .mentioned)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(status.requireID())/reblogged",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
