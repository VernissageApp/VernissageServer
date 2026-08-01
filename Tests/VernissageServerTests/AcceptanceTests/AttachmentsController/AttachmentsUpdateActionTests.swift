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
        
        @Test
        func `Attachment should be updated with correct data`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rickbutix")
            let location = try await application.createLocation(name: "Wrocław")
            let license = try await application.getLicense(code: "CC BY-NC-SA")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
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
                                                                longitude: "17,92533",
                                                                flash: "Fired",
                                                                focalLength: "56")
            
            // Act.
            let response = try await application.sendRequest(
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
            #expect(attachmentExif.latitude == temporaryAttachmentDto.latitude, "Attachment latitude should be correct.")
            #expect(attachmentExif.longitude == temporaryAttachmentDto.longitude, "Attachment longitude should be correct.")
            #expect(attachmentExif.flash == temporaryAttachmentDto.flash, "Attachment flash should be correct.")
            #expect(attachmentExif.focalLength == temporaryAttachmentDto.focalLength, "Attachment focalLength should be correct.")

            #expect(attachmentLocation.stringId() == location.stringId(), "Attachment location id should be correct.")
            #expect(attachmentLocation.name == location.name, "Attachment location name should be correct.")
            #expect(attachmentLicense.name == license?.name, "Attachment license name should be correct.")
        }

        @Test
        func `Updating Exif of attachment assigned to status should synchronize timelines and amounts`() async throws {
            let user = try await application.createUser(userName: "attachmentexifsynchronization")
            let attachment = try await application.createAttachment(
                user: user,
                make: "Attachment Camera",
                model: "Attachment Camera X1",
                lens: "Attachment Lens 50mm",
                film: "Attachment Film 400"
            )
            defer {
                application.clearFiles(attachments: [attachment])
            }

            let attachmentId = try #require(attachment.stringId())
            let status = try await application.createStatus(
                user: user,
                note: "Status used to test attachment Exif synchronization",
                attachmentIds: [attachmentId]
            )

            let previousCamera = try #require(
                try await Camera.query(on: application.db)
                    .filter(\.$nameNormalized == "ATTACHMENT CAMERA X1")
                    .first()
            )
            let previousLens = try #require(
                try await Lens.query(on: application.db)
                    .filter(\.$nameNormalized == "ATTACHMENT LENS 50MM")
                    .first()
            )
            let previousFilm = try #require(
                try await Film.query(on: application.db)
                    .filter(\.$nameNormalized == "ATTACHMENT FILM 400")
                    .first()
            )

            let temporaryAttachmentDto = TemporaryAttachmentDto(
                id: attachmentId,
                url: "",
                previewUrl: "",
                make: "Updated Attachment Camera",
                model: "Updated Attachment Camera X2",
                lens: "Updated Attachment Lens 85mm",
                film: "Updated Attachment Film 800"
            )

            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/attachments/\(attachmentId)",
                method: .PUT,
                body: temporaryAttachmentDto
            )

            #expect(response.status == .ok)

            let updatedCamera = try #require(
                try await Camera.query(on: application.db)
                    .filter(\.$nameNormalized == "UPDATED ATTACHMENT CAMERA X2")
                    .first()
            )
            let updatedLens = try #require(
                try await Lens.query(on: application.db)
                    .filter(\.$nameNormalized == "UPDATED ATTACHMENT LENS 85MM")
                    .first()
            )
            let updatedFilm = try #require(
                try await Film.query(on: application.db)
                    .filter(\.$nameNormalized == "UPDATED ATTACHMENT FILM 800")
                    .first()
            )

            #expect(
                try await Camera.query(on: application.db)
                    .filter(\.$id == previousCamera.requireID())
                    .first()?
                    .amount == 0
            )
            #expect(
                try await Lens.query(on: application.db)
                    .filter(\.$id == previousLens.requireID())
                    .first()?
                    .amount == 0
            )
            #expect(
                try await Film.query(on: application.db)
                    .filter(\.$id == previousFilm.requireID())
                    .first()?
                    .amount == 0
            )
            #expect(updatedCamera.amount == 1)
            #expect(updatedLens.amount == 1)
            #expect(updatedFilm.amount == 1)
            #expect(
                try await CameraStatus.query(on: application.db)
                    .filter(\.$id.$status.$id == status.requireID())
                    .filter(\.$id.$camera.$id == updatedCamera.requireID())
                    .count() == 1
            )
            #expect(
                try await LensStatus.query(on: application.db)
                    .filter(\.$id.$status.$id == status.requireID())
                    .filter(\.$id.$lens.$id == updatedLens.requireID())
                    .count() == 1
            )
            #expect(
                try await FilmStatus.query(on: application.db)
                    .filter(\.$id.$status.$id == status.requireID())
                    .filter(\.$id.$film.$id == updatedFilm.requireID())
                    .count() == 1
            )
        }
        
        @Test
        func `Attachment should not be updated with too long descrioption`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "martinbutix")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                                url: "",
                                                                previewUrl: "",
                                                                description: String.createRandomString(length: 2001))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Attachment should not be updated with too long blurhash`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondbutix")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                                url: "",
                                                                previewUrl: "",
                                                                blurhash: String.createRandomString(length: 101))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
        
        @Test
        func `Attachment should not be updated when other user tries to update`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annabutix")
            let user = try await application.createUser(userName: "martabutix")
            let attachment = try await application.createAttachment(user: user)
            defer {
                let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
                try? FileManager.default.removeItem(at: orginalFileUrl)
                
                let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                                url: "",
                                                                previewUrl: "",
                                                                description: "Changed...")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
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
