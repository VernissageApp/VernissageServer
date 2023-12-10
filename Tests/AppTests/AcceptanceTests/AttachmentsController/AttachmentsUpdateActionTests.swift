//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class AttachmentsUpdateActionTests: CustomTestCase {
    func testAttachmentShouldBeUpdatedWithCorrectData() async throws {

        // Arrange.
        let user = try await User.create(userName: "rickbutix")
        let location = try await Location.create(name: "Wrocław")
        let license = try await License.get(code: "CC BY-NC-SA")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                            url: "",
                                                            previewUrl: "",
                                                            description: "This is description...",
                                                            blurhash: "BLURHASH",
                                                            make: "Sony",
                                                            model: "A7IV",
                                                            lens: "Viltrox 85",
                                                            createDate: "2023-07-13T20:15:35.319+02:00",
                                                            focalLenIn35mmFilm: "85",
                                                            fNumber: "f/1.8",
                                                            exposureTime: "1/250",
                                                            photographicSensitivity: "2000",
                                                            locationId: location.stringId(),
                                                            licenseId: license?.stringId())
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "rickbutix", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            body: temporaryAttachmentDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        guard let updatedAttachment = try? await Attachment.get(userId: user.requireID()) else {
            XCTAssert(true, "Attachment was not found")
            return
        }

        guard let attachmentExif = updatedAttachment.exif else {
            XCTAssert(true, "Exif metadata was not found")
            return
        }

        guard let attachmentLocation = updatedAttachment.location else {
            XCTAssert(true, "Location was not found")
            return
        }

        guard let attachmentLicense = updatedAttachment.license else {
            XCTAssert(true, "License was not found")
            return
        }
        
        XCTAssertEqual(updatedAttachment.stringId(), temporaryAttachmentDto.id, "Attachment id should be correct.")
        XCTAssertEqual(updatedAttachment.description, temporaryAttachmentDto.description, "Attachment description should be correct.")
        XCTAssertEqual(updatedAttachment.blurhash, temporaryAttachmentDto.blurhash, "Attachment blurhash should be correct.")
        XCTAssertEqual(attachmentExif.make, temporaryAttachmentDto.make, "Attachment make should be correct.")
        XCTAssertEqual(attachmentExif.model, temporaryAttachmentDto.model, "Attachment model privileges should be correct.")
        XCTAssertEqual(attachmentExif.lens, temporaryAttachmentDto.lens, "Attachment lens should be correct.")
        XCTAssertEqual(attachmentExif.createDate, temporaryAttachmentDto.createDate, "Attachment createDate should be correct.")
        XCTAssertEqual(attachmentExif.focalLenIn35mmFilm, temporaryAttachmentDto.focalLenIn35mmFilm, "Attachment focalLenIn35mmFilm should be correct.")
        XCTAssertEqual(attachmentExif.fNumber, temporaryAttachmentDto.fNumber, "Attachment fNumber should be correct.")
        XCTAssertEqual(attachmentExif.exposureTime, temporaryAttachmentDto.exposureTime, "Attachment exposureTime should be correct.")
        XCTAssertEqual(attachmentExif.photographicSensitivity, temporaryAttachmentDto.photographicSensitivity, "Attachment photographicSensitivity should be correct.")
        XCTAssertEqual(attachmentLocation.stringId(), location.stringId(), "Attachment location id should be correct.")
        XCTAssertEqual(attachmentLocation.name, location.name, "Attachment location name should be correct.")
        XCTAssertEqual(attachmentLicense.name, license?.name, "Attachment license name should be correct.")
    }
    
    func testAttachmentShouldNotBeUpdatedWithTooLongDescrioption() async throws {

        // Arrange.
        let user = try await User.create(userName: "martinbutix")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                            url: "",
                                                            previewUrl: "",
                                                            description:
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "123456789012345678901234567890123456789012345678901")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "martinbutix", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            data: temporaryAttachmentDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("description"), "is greater than maximum of 500 character(s) and is not null")
    }
    
    func testAttachmentShouldNotBeUpdatedWithTooLongBlurhash() async throws {

        // Arrange.
        let user = try await User.create(userName: "trondbutix")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                            url: "",
                                                            previewUrl: "",
                                                            blurhash:
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "12345678901234567890123456789012345678901234567890" +
                                                                "123456789012345678901234567890123456789012345678901")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trondbutix", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            data: temporaryAttachmentDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("blurhash"), "is greater than maximum of 100 character(s) and is not null")
    }
    
    func testAttachmentShouldNotBeUpdatedWhenOtherUserTriesToUpdate() async throws {

        // Arrange.
        _ = try await User.create(userName: "annabutix")
        let user = try await User.create(userName: "martabutix")
        let attachment = try await Attachment.create(user: user)
        defer {
            let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
            try? FileManager.default.removeItem(at: orginalFileUrl)
            
            let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
            try? FileManager.default.removeItem(at: smalFileUrl)
        }
        
        let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                            url: "",
                                                            previewUrl: "",
                                                            description: "Changed...")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "annabutix", password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            data: temporaryAttachmentDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
