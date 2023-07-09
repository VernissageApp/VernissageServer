//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class HeadersDeleteActionTests: CustomTestCase {
    
    func testHeaderShouldBeDeletedForCorrectRequest() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "triszero")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/AppTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "triszero", password: "p@ssword"),
            to: "/users/@triszero/header",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        let userAfterRequest = try await User.get(userName: "triszero")
        let headerFileName = userAfterRequest.headerFileName
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "triszero", password: "p@ssword"),
            to: "/users/@triszero/header",
            method: .DELETE
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let userAfterDelete = try await User.get(userName: "triszero")
        XCTAssertNil(userAfterDelete.headerFileName, "Header file name should be deleted from database.")
        
        let headerFilePath = "\(FileManager.default.currentDirectoryPath)/Public/storage/\(headerFileName!)"
        XCTAssertFalse(FileManager.default.fileExists(atPath: headerFilePath), "File should not exists on disk.")
    }
    
    func testHeaderShouldNotBeDeletedWhenNotAuthorizedUserTriesToDeleteHeader() async throws {
        // Arrange.
        _ = try await User.create(userName: "romanzero")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/users/@romanzero/header",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testHeaderShouldNotBeDeleteWhenDifferentUserDeletesHeader() async throws {
        // Arrange.
        _ = try await User.create(userName: "vikizero")
        _ = try await User.create(userName: "erikzero")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikzero", password: "p@ssword"),
            to: "/users/@vikizero/header",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
