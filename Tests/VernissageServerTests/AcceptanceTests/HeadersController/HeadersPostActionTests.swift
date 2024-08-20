//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class HeadersPostActionTests: CustomTestCase {
    
    func testHeaderShouldBeSavedWhenImageIsProvided() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "triskulka")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "triskulka", password: "p@ssword"),
            to: "/headers/@triskulka",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(userName: "triskulka")
        XCTAssertNotNil(userAfterRequest.headerFileName, "Header should be set up in database.")
        
        let headerFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(userAfterRequest.headerFileName!)")
        let headerFile = try Data(contentsOf: headerFileUrl)
        XCTAssertNotNil(headerFile, "Header file sholud be saved into the disk.")
        
        try FileManager.default.removeItem(at: headerFileUrl)
    }
    
    func testHeaderShouldNotBeChangedWhenNotAuthorizedUserTriesToUpdateHeader() async throws {
        // Arrange.
        _ = try await User.create(userName: "romankulka")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/headers/@romankulka",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testHeaderShouldNotBeChangedWhenDifferentUserUpdatesHeader() async throws {
        // Arrange.
        _ = try await User.create(userName: "vikikulka")
        _ = try await User.create(userName: "erikkulka")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikkulka", password: "p@ssword"),
            to: "/headers/@vikikulka",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testHeaderShouldNotBeChangedWhenFileIsNotProvided() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "tedkulka")
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tedkulka", password: "p@ssword"),
            to: "/headers/@tedkulka",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "missingImage", "Error code should be equal 'missingImage'.")
    }
}
