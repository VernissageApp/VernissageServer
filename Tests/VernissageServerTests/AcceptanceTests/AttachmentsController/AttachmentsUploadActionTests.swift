//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class AttachmentsUploadActionTests: CustomTestCase {
    
    func testAttachmentShouldBeSavedWhenImageIsProvided() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "vaclavexal")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "vaclavexal", password: "p@ssword"),
            to: "/attachments",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
        let attachment = try await Attachment.get(userId: user.requireID())
        let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
        let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")

        defer {
            try? FileManager.default.removeItem(at: orginalFileUrl)
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        XCTAssertNotNil(attachment, "Attachment should be set up in database.")
        XCTAssertNotNil(attachment.$originalFile, "Attachment orginal file should be set up in database.")
        XCTAssertNotNil(attachment.$smallFile, "Attachment small file should be set up in database.")
                        
        let orginalFile = try Data(contentsOf: orginalFileUrl)
        XCTAssertNotNil(orginalFile, "Orginal attachment file sholud be saved into the disk.")

        let smallFile = try Data(contentsOf: orginalFileUrl)
        XCTAssertNotNil(smallFile, "Small attachment file sholud be saved into the disk.")
    }
    
    func testAttachmentShouldNotBeUploadedWhenNotAuthorizedUserTriesToUpload() async throws {
        
        // Arrange.        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/attachments",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testAttachmentShouldNotBeUploadedWhenFileIsNotProvided() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rafaelexal")
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "rafaelexal", password: "p@ssword"),
            to: "/attachments",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "missingImage", "Error code should be equal 'missingImage'.")
    }
}
