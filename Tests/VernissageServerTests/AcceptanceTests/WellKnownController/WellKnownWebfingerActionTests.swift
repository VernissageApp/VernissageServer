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

@Suite("GET /webfinger", .serialized, .tags(.wellKnown))
struct WellKnownWebfingerActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Webfinger should be returned for existing actor")
    func webfingerShouldBeReturnedForExistingActor() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "ronaldtrix")
        
        // Act.
        let webfingerDto = try application.getResponse(
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
    
    @Test("Webfinger should return jrd+json content type header")
    func webfingerShouldReturnJrdJsonContentTypeHeader() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "tobintrix")
        
        // Act.
        let response = try application.sendRequest(
            to: "/.well-known/webfinger?resource=acct:tobintrix@localhost:8080",
            version: .none,
            method: .GET
        )
        
        // Assert.
        #expect(response.headers.contentType?.description == "application/jrd+json; charset=utf-8", "Returned content type should be application/jrd+json.")
    }
    
    @Test("Webfinger should return application actor")
    func webfingerShouldReturnApplicationActor() async throws {
        
        // Act.
        let webfingerDto = try application.getResponse(
            to: "/.well-known/webfinger?resource=acct:localhost@localhost",
            version: .none,
            decodeTo: WebfingerDto.self
        )
        
        // Assert.
        #expect(webfingerDto.subject == "acct:localhost@localhost", "Property 'subject' should be equal.")
    }
    
    @Test("Webfinger should not be returned for not existing actor")
    func webfingerShouldNotBeReturnedForNotExistingActor() throws {

        // Act.
        let response = try application.sendRequest(
            to: "/.well-known/webfinger?resource=acct:unknown@localhost:8080",
            version: .none,
            method: .GET)

        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}

