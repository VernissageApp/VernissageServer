//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("ActivityPubActor (GET /actors/:username/alsoKnownAs)", .serialized, .tags(.actors))
    struct ActivityPubActorsAlsoKnownAsActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Aliases collection should be returned for actor`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "aliastarget")
            _ = try await application.createUserAlias(userId: user.requireID(),
                                                      alias: "olduser@old.server",
                                                      activityPubProfile: "https://old.server/users/olduser")
            
            // Act.
            let collection = try await application.getResponse(
                to: "/actors/aliastarget/alsoKnownAs",
                version: .none,
                decodeTo: CollectionDto.self
            )
            
            // Assert.
            #expect(collection.id == "http://localhost:8080/actors/aliastarget/alsoKnownAs")
            #expect(collection.totalItems == 1)
            #expect(collection.items.first == "https://old.server/users/olduser")
        }
    }
}
