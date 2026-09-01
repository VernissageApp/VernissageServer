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
    
    @Suite("WellKnown (GET /.well-known/webfinger)", .serialized, .tags(.wellKnown))
    struct WellKnownWebfingerActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Webfinger should be returned for existing actor`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ronaldtrix")
            
            // Act.
            let webfingerDto = try await application.getResponse(
                to: "/.well-known/webfinger?resource=acct:ronaldtrix@localhost:8080",
                version: .none,
                decodeTo: WebfingerDto.self
            )
            
            // Assert.
            #expect(webfingerDto.subject == "acct:ronaldtrix@localhost:8080", "Property 'subject' should be equal.")
            #expect(webfingerDto.aliases?.first(where: { $0 == "http://localhost:8080/@ronaldtrix" }) != nil, "Property 'alias' doesn't contains alias")
            #expect(webfingerDto.aliases?.first(where: { $0 == "http://localhost:8080/actors/ronaldtrix" }) != nil, "Property 'alias' doesn't contains alias")
            #expect(
                webfingerDto.links.first(where: { $0.rel == "self"})?.href == "http://localhost:8080/actors/ronaldtrix",
                "Property 'links' should contains correct 'self' item.")
            #expect(
                webfingerDto.links.first(where: { $0.rel == "http://webfinger.net/rel/profile-page"})?.href == "http://localhost:8080/@ronaldtrix",
                "Property 'links' should contains correct 'profile-page' item.")
        }

        @Test
        func `Webfinger should be returned for local profile URL`() async throws {

            // Arrange.
            _ = try await application.createUser(userName: "profileurltrix")

            // Act.
            let webfingerDto = try await application.getResponse(
                to: "/.well-known/webfinger?resource=http%3A%2F%2Flocalhost%3A8080%2F%40profileurltrix",
                version: .none,
                decodeTo: WebfingerDto.self
            )

            // Assert.
            #expect(webfingerDto.subject == "acct:profileurltrix@localhost:8080", "Property 'subject' should be equal.")
        }

        @Test
        func `Webfinger should be returned for local actor URL`() async throws {

            // Arrange.
            _ = try await application.createUser(userName: "actorurltrix")

            // Act.
            let webfingerDto = try await application.getResponse(
                to: "/.well-known/webfinger?resource=http%3A%2F%2Flocalhost%3A8080%2Factors%2Factorurltrix",
                version: .none,
                decodeTo: WebfingerDto.self
            )

            // Assert.
            #expect(webfingerDto.subject == "acct:actorurltrix@localhost:8080", "Property 'subject' should be equal.")
        }

        @Test
        func `Webfinger should not resolve URL from another host`() async throws {

            // Arrange.
            _ = try await application.createUser(userName: "externalurltrix")

            // Act.
            let response = try await application.sendRequest(
                to: "/.well-known/webfinger?resource=https%3A%2F%2Fexample.com%2Factors%2Fexternalurltrix",
                version: .none,
                method: .GET
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Webfinger should return jrd+json content type header`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tobintrix")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/.well-known/webfinger?resource=acct:tobintrix@localhost:8080",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.headers.contentType?.description == "application/jrd+json; charset=utf-8", "Returned content type should be application/jrd+json.")
        }
        
        @Test
        func `Webfinger should return application actor`() async throws {
            
            // Act.
            let webfingerDto = try await application.getResponse(
                to: "/.well-known/webfinger?resource=acct:localhost@localhost",
                version: .none,
                decodeTo: WebfingerDto.self
            )
            
            // Assert.
            #expect(webfingerDto.subject == "acct:localhost@localhost", "Property 'subject' should be equal.")
        }
        
        @Test
        func `Webfinger should not be returned for not existing actor`() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/.well-known/webfinger?resource=acct:unknown@localhost:8080",
                version: .none,
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
