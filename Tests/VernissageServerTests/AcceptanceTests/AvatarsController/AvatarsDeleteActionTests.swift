//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AvatarsDeleteActionTests: CustomTestCase {
    
    func testAvatarShouldBeDeletedForCorrectRequest() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "trisfuks")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "trisfuks", password: "p@ssword"),
            to: "/avatars/@trisfuks",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        let userAfterRequest = try await User.get(userName: "trisfuks")
        let avatarFileName = userAfterRequest.avatarFileName
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "trisfuks", password: "p@ssword"),
            to: "/avatars/@trisfuks",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let userAfterDelete = try await User.get(userName: "trisfuks")
        XCTAssertNil(userAfterDelete.avatarFileName, "Avatar file name should be deleted from database.")
        
        let avatarFilePath = "\(FileManager.default.currentDirectoryPath)/Public/storage/\(avatarFileName!)"
        XCTAssertFalse(FileManager.default.fileExists(atPath: avatarFilePath), "File should not exists on disk.")
    }
    
    func testAvatarShouldNotBeDeletedWhenNotAuthorizedUserTriesToDeleteAvatar() async throws {
        // Arrange.
        _ = try await User.create(userName: "romanfuks")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/avatars/@romanfuks",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testAvatarShouldNotBeDeleteWhenDifferentUserDeletesAvatar() async throws {
        // Arrange.
        _ = try await User.create(userName: "vikifuks")
        _ = try await User.create(userName: "erikfuks")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikfuks", password: "p@ssword"),
            to: "/avatars/@vikifuks",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
