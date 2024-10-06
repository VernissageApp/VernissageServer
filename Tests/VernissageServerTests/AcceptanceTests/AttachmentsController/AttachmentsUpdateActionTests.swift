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
    
    @Suite("Attachments (PUT /attachments)", .serialized, .tags(.attachments))
    struct AttachmentsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Attachment should be updated with correct data")
        func attachmentShouldBeUpdatedWithCorrectData() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rickbutix")
            let location = try await application.createLocation(name: "Wrocław")
            let license = try await application.getLicense(code: "CC BY-NC-SA")
            let attachment = try await application.createAttachment(user: user)
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
                                                                software: "Capture One",
                                                                film: "Kodak 400",
                                                                chemistry: "SilverChem",
                                                                scanner: "Adobe Scanner",
                                                                locationId: location.stringId(),
                                                                licenseId: license?.stringId(),
                                                                latitude: "50,67211",
                                                                longitude: "17,92533")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "rickbutix", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .PUT,
                body: temporaryAttachmentDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            guard let updatedAttachment = try? await application.getAttachment(userId: user.requireID()) else {
                #expect(Bool(false), "Attachment was not found")
                return
            }
            
            guard let attachmentExif = updatedAttachment.exif else {
                #expect(Bool(false), "Exif metadata was not found")
                return
            }
            
            guard let attachmentLocation = updatedAttachment.location else {
                #expect(Bool(false), "Location was not found")
                return
            }
            
            guard let attachmentLicense = updatedAttachment.license else {
                #expect(Bool(false), "License was not found")
                return
            }
            
            #expect(updatedAttachment.stringId() == temporaryAttachmentDto.id, "Attachment id should be correct.")
            #expect(updatedAttachment.description == temporaryAttachmentDto.description, "Attachment description should be correct.")
            #expect(updatedAttachment.blurhash == temporaryAttachmentDto.blurhash, "Attachment blurhash should be correct.")
            #expect(attachmentExif.make == temporaryAttachmentDto.make, "Attachment make should be correct.")
            #expect(attachmentExif.model == temporaryAttachmentDto.model, "Attachment model privileges should be correct.")
            #expect(attachmentExif.lens == temporaryAttachmentDto.lens, "Attachment lens should be correct.")
            #expect(attachmentExif.createDate == temporaryAttachmentDto.createDate, "Attachment createDate should be correct.")
            #expect(attachmentExif.focalLenIn35mmFilm == temporaryAttachmentDto.focalLenIn35mmFilm, "Attachment focalLenIn35mmFilm should be correct.")
            #expect(attachmentExif.fNumber == temporaryAttachmentDto.fNumber, "Attachment fNumber should be correct.")
            #expect(attachmentExif.exposureTime == temporaryAttachmentDto.exposureTime, "Attachment exposureTime should be correct.")
            #expect(attachmentExif.photographicSensitivity == temporaryAttachmentDto.photographicSensitivity, "Attachment photographicSensitivity should be correct.")
            #expect(attachmentExif.software == temporaryAttachmentDto.software, "Attachment software should be correct.")
            #expect(attachmentExif.film == temporaryAttachmentDto.film, "Attachment film should be correct.")
            #expect(attachmentExif.chemistry == temporaryAttachmentDto.chemistry, "Attachment chemistry should be correct.")
            #expect(attachmentExif.scanner == temporaryAttachmentDto.scanner, "Attachment scanner should be correct.")
            #expect(attachmentExif.latitude == temporaryAttachmentDto.latitude, "Attachment film should be correct.")
            #expect(attachmentExif.longitude == temporaryAttachmentDto.longitude, "Attachment film should be correct.")

            #expect(attachmentLocation.stringId() == location.stringId(), "Attachment location id should be correct.")
            #expect(attachmentLocation.name == location.name, "Attachment location name should be correct.")
            #expect(attachmentLicense.name == license?.name, "Attachment license name should be correct.")
        }
        
        @Test("Attachment should not be updated with too long descrioption")
        func attachmentShouldNotBeUpdatedWithTooLongDescrioption() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "martinbutix")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                                url: "",
                                                                previewUrl: "",
                                                                description: String.createRandomString(length: 2001))
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "martinbutix", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .PUT,
                data: temporaryAttachmentDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("description") == "is greater than maximum of 2000 character(s) and is not null")
        }
        
        @Test("Attachment should not be updated with too long blurhash")
        func attachmentShouldNotBeUpdatedWithTooLongBlurhash() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondbutix")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                                url: "",
                                                                previewUrl: "",
                                                                blurhash: String.createRandomString(length: 101))
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "trondbutix", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .PUT,
                data: temporaryAttachmentDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("blurhash") == "is greater than maximum of 100 character(s) and is not null")
        }
        
        @Test("Attachment should not be updated when other user tries to update")
        func attachmentShouldNotBeUpdatedWhenOtherUserTriesToUpdate() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annabutix")
            let user = try await application.createUser(userName: "martabutix")
            let attachment = try await application.createAttachment(user: user)
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
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "annabutix", password: "p@ssword"),
                to: "/attachments/\(attachment.stringId() ?? "")",
                method: .PUT,
                data: temporaryAttachmentDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
