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

extension AvatarsControllerTests {
    
    @Suite("DELETE /:username", .serialized, .tags(.avatars))
    struct AvatarsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Avatar should be deleted for correct request")
        func avatarShouldBeDeletedForCorrectRequest() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trisfuks")
            
            let path = FileManager.default.currentDirectoryPath
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            _ = try application.sendRequest(
                as: .user(userName: "trisfuks", password: "p@ssword"),
                to: "/avatars/@trisfuks",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            let userAfterRequest = try await application.getUser(userName: "trisfuks")
            let avatarFileName = userAfterRequest.avatarFileName
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "trisfuks", password: "p@ssword"),
                to: "/avatars/@trisfuks",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let userAfterDelete = try await application.getUser(userName: "trisfuks")
            #expect(userAfterDelete.avatarFileName == nil, "Avatar file name should be deleted from database.")
            
            let avatarFilePath = "\(FileManager.default.currentDirectoryPath)/Public/storage/\(avatarFileName!)"
            #expect(FileManager.default.fileExists(atPath: avatarFilePath) == false, "File should not exists on disk.")
        }
        
        @Test("Avatar should not be deleted when not authorized user tries to delete avatar")
        func avatarShouldNotBeDeletedWhenNotAuthorizedUserTriesToDeleteAvatar() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "romanfuks")
            
            // Act.
            let response = try application.sendRequest(
                to: "/avatars/@romanfuks",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Avatar should not be delete when different user deletes avatar")
        func avatarShouldNotBeDeleteWhenDifferentUserDeletesAvatar() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vikifuks")
            _ = try await application.createUser(userName: "erikfuks")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "erikfuks", password: "p@ssword"),
                to: "/avatars/@vikifuks",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
    }
}
