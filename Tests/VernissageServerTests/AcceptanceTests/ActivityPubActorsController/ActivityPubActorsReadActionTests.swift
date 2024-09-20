//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("ActivityPubActor (GET /actors/:username)", .serialized, .tags(.actors))
    struct ActivityPubActorsReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Actor profile should be returned for existing actor")
        func actorProfileShouldBeReturnedForExistingActor() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tronddedal")
            _ = try await application.createFlexiField(key: "KEY1", value: "VALUE-A", isVerified: true, userId: user.requireID())
            _ = try await application.createFlexiField(key: "KEY2", value: "VALUE-B", isVerified: false, userId: user.requireID())
            
            // Act.
            let personDto = try application.getResponse(
                to: "/actors/tronddedal",
                version: .none,
                decodeTo: PersonDto.self
            )
            
            // Assert.
            #expect(personDto.id == "http://localhost:8080/actors/tronddedal", "Property 'id' is not valid.")
            #expect(personDto.type == "Person", "Property 'type' is not valid.")
            #expect(personDto.inbox == "http://localhost:8080/actors/tronddedal/inbox", "Property 'inbox' is not valid.")
            #expect(personDto.outbox == "http://localhost:8080/actors/tronddedal/outbox", "Property 'outbox' is not valid.")
            #expect(personDto.following == "http://localhost:8080/actors/tronddedal/following", "Property 'inbox' is not valid.")
            #expect(personDto.followers == "http://localhost:8080/actors/tronddedal/followers", "Property 'outbox' is not valid.")
            #expect(personDto.preferredUsername == "tronddedal", "Property 'preferredUsername' is not valid.")
            
            #expect(personDto.attachment?[0].name == "KEY1", "Property 'fields[0].name' is not valid.")
            #expect(personDto.attachment?[1].name == "KEY2", "Property 'fields[1].name' is not valid.")
            
            #expect(personDto.attachment?[0].value == "<p>VALUE-A</p>", "Property 'fields[0].value' is not valid.")
            #expect(personDto.attachment?[1].value == "<p>VALUE-B</p>", "Property 'fields[1].value' is not valid.")
            
            #expect(personDto.attachment?[0].type == "PropertyValue", "Property 'fields[0].type' is not valid.")
            #expect(personDto.attachment?[1].type == "PropertyValue", "Property 'fields[1].type' is not valid.")
        }
        
        @Test("Actor profile should not be returned for not existing actor")
        func actorProfileShouldNotBeReturnedForNotExistingActor() throws {
            
            // Act.
            let response = try application.sendRequest(to: "/actors/unknown@host.com",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
