//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AvatarsPostActionTests: CustomTestCase {
    
    func testAvatarShouldBeSavedWhenImageIsProvided() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "trismerigot")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "trismerigot", password: "p@ssword"),
            to: "/avatars/@trismerigot",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(userName: "trismerigot")
        XCTAssertNotNil(userAfterRequest.avatarFileName, "Avatar should be set up in database.")
        
        let avatarFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(userAfterRequest.avatarFileName!)")
        let avatarFile = try Data(contentsOf: avatarFileUrl)
        XCTAssertNotNil(avatarFile, "Avatar file sholud be saved into the disk.")
        
        try FileManager.default.removeItem(at: avatarFileUrl)
    }
    
    func testAvatarShouldNotBeChangedWhenNotAuthorizedUserTriesToUpdateAvatar() async throws {
        // Arrange.
        _ = try await User.create(userName: "romanmerigot")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/avatars/@romanmerigot",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testAvatarShouldNotBeChangedWhenDifferentUserUpdatesAvatar() async throws {
        // Arrange.
        _ = try await User.create(userName: "vikimerigot")
        _ = try await User.create(userName: "erikmerigot")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikmerigot", password: "p@ssword"),
            to: "/avatars/@vikimerigot",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testAvatarShouldNotBeChangedWhenFileIsNotProvided() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "tedmerigot")
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tedmerigot", password: "p@ssword"),
            to: "/avatars/@tedmerigot",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "missingImage", "Error code should be equal 'missingImage'.")
    }
}
