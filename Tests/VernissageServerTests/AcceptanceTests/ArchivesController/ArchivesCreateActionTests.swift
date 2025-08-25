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
    
    @Suite("Archives (POST /archives)", .serialized, .tags(.invitations))
    struct ArchivesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Archive should be added for authorized user")
        func archiveShouldBeAddedForAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robintopin")
            
            // Act.
            let archive = try await application.getResponse(
                as: .user(userName: "robintopin", password: "p@ssword"),
                to: "/archives",
                method: .POST,
                decodeTo: ArchiveDto.self
            )
            
            // Assert.
            #expect(archive.id != nil, "Archive should be generated.")
            #expect(archive.status == .new, "Archive should have new status.")
        }

        @Test("Archive should not be added when there is new archive")
        func archiveShouldNotBeAddedWhenThereIsNewArchive() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annatopin")
            _ = try await application.createArchive(userId: user.requireID())
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annatopin", password: "p@ssword"),
                to: "/archives",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "requestWaitingForProcessing", "Error code should be equal 'requestWaitingForProcessing'.")
        }
        
        @Test("Archive should not be added when there is processing archive")
        func archiveShouldNotBeAddedWhenThereIsProcessingArchive() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rafaltopin")
            let archive = try await application.createArchive(userId: user.requireID())
            try await application.set(archive: archive, status: .processing)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "rafaltopin", password: "p@ssword"),
                to: "/archives",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "requestWaitingForProcessing", "Error code should be equal 'requestWaitingForProcessing'.")
        }
        
        @Test("Archive should not be added when there is ready archive")
        func archiveShouldNotBeAddedWhenThereIsReadyArchive() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "georgetopin")
            let archive = try await application.createArchive(userId: user.requireID())
            try await application.set(archive: archive, status: .ready)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "georgetopin", password: "p@ssword"),
                to: "/archives",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "processedRequestsAlreadyExist", "Error code should be equal 'processedRequestsAlreadyExist'.")
        }
        
        @Test("Archive should not be added when user is not authorized")
        func archiveShouldNotBeAddeddWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/archives", method: .POST)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
