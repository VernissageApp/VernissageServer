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
    
    @Suite("Avatars (POST /avatars/:username)", .serialized, .tags(.avatars))
    struct AvatarsPostActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Avatar should be saved when image is provided")
        func avatarShouldBeSavedWhenImageIsProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trismerigot")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "trismerigot", password: "p@ssword"),
                to: "/avatars/@trismerigot",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(userName: "trismerigot")
            #expect(userAfterRequest.avatarFileName != nil, "Avatar should be set up in database.")
            
            let avatarFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(userAfterRequest.avatarFileName!)")
            let avatarFile = try Data(contentsOf: avatarFileUrl)
            #expect(avatarFile != nil, "Avatar file sholud be saved into the disk.")
            
            try FileManager.default.removeItem(at: avatarFileUrl)
        }
        
        @Test("Avatar should not be changed when not authorized user tries to update avatar")
        func avatarShouldNotBeChangedWhenNotAuthorizedUserTriesToUpdateAvatar() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "romanmerigot")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/avatars/@romanmerigot",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Avatar should not be changed when different user updates avatar")
        func avatarShouldNotBeChangedWhenDifferentUserUpdatesAvatar() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vikimerigot")
            _ = try await application.createUser(userName: "erikmerigot")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "erikmerigot", password: "p@ssword"),
                to: "/avatars/@vikimerigot",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Avatar should not be changed when file is not provided")
        func avatarShouldNotBeChangedWhenFileIsNotProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tedmerigot")
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "tedmerigot", password: "p@ssword"),
                to: "/avatars/@tedmerigot",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "missingImage", "Error code should be equal 'missingImage'.")
        }
    }
}
