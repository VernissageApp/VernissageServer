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
    
    @Suite("Attachments (POST /attachments)", .serialized, .tags(.attachments))
    struct AttachmentsUploadActionTests {
        struct ColorProfileCase: Sendable {
            let assetFileName: String
            let expectedProfile: String
        }

        private static let colorProfileCases = [
            ColorProfileCase(assetFileName: "2048-adobeRGB.jpg", expectedProfile: "sRGB IEC61966-2.1"),
            ColorProfileCase(assetFileName: "2048-P3.jpg", expectedProfile: "sRGB IEC61966-2.1"),
            ColorProfileCase(assetFileName: "2048-sRGB.jpg", expectedProfile: "sRGB IEC61966-2.1"),
            ColorProfileCase(assetFileName: "6963-adobeRGB.jpg", expectedProfile: "sRGB IEC61966-2.1"),
            ColorProfileCase(assetFileName: "6963-P3.jpg", expectedProfile: "sRGB IEC61966-2.1"),
            ColorProfileCase(assetFileName: "6963-sRGB.jpg", expectedProfile: "sRGB IEC61966-2.1")
        ]

        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Attachment should be saved when image is provided`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "vaclavexal")
            
            let path = application.directory.workingDirectory
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vaclavexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let attachment = try await application.getAttachment(userId: user.requireID())
            let orginalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
            let smalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
            
            defer {
                try? FileManager.default.removeItem(at: orginalFileUrl)
                try? FileManager.default.removeItem(at: smalFileUrl)
            }
            
            #expect(attachment.$originalFile.value != nil, "Attachment orginal file should be set up in database.")
            #expect(attachment.$smallFile.value != nil, "Attachment small file should be set up in database.")
            
            let orginalFile = try? Data(contentsOf: orginalFileUrl)
            #expect(orginalFile != nil, "Orginal attachment file sholud be saved into the disk.")
            
            let smallFile = try? Data(contentsOf: orginalFileUrl)
            #expect(smallFile != nil, "Small attachment file sholud be saved into the disk.")
        }

        @Test
        func `Attachment should be saved when webp image is provided`() async throws {

            // Arrange.
            let user = try await application.createUser(userName: "romekwebp")

            let path = application.directory.workingDirectory
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/003.webp"))

            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "003.webp", data: imageFile, mimeType: "image/webp")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "romekwebp", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )

            let attachment = try await application.getAttachment(userId: user.requireID())
            let originalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
            let smallFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")
            
            defer {
                try? FileManager.default.removeItem(at: originalFileUrl)
                try? FileManager.default.removeItem(at: smallFileUrl)
            }
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
        }

        @Test(arguments: Self.colorProfileCases)
        func `Uploaded image should export and save with sRGB color profile`(testCase: ColorProfileCase) async throws {

            // Arrange.
            let userName = "icc\(String.createRandomString(length: 12).lowercased())"
            let user = try await application.createUser(userName: userName)

            let path = application.directory.workingDirectory
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/\(testCase.assetFileName)"))

            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: testCase.assetFileName, data: imageFile, mimeType: "image/jpeg")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: userName, password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")

            let attachment = try await application.getAttachment(userId: user.requireID())
            let originalFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.originalFile.fileName)")
            let smallFileUrl = URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(attachment.smallFile.fileName)")

            defer {
                try? FileManager.default.removeItem(at: originalFileUrl)
                try? FileManager.default.removeItem(at: smallFileUrl)
            }

            let originalData = try Data(contentsOf: originalFileUrl)
            let smallData = try Data(contentsOf: smallFileUrl)

            let originalEmbeddedProfile = originalData.embeddedIccProfileDescriptionFromJpeg()
            let smallEmbeddedProfile = smallData.embeddedIccProfileDescriptionFromJpeg()
            let originalProfile = originalEmbeddedProfile ?? "sRGB IEC61966-2.1"
            let smallProfile = smallEmbeddedProfile ?? "sRGB IEC61966-2.1"

            #expect(originalProfile == testCase.expectedProfile, "Original image for '\(testCase.assetFileName)' should keep expected color profile behavior.")
            #expect(smallProfile == testCase.expectedProfile, "Small image for '\(testCase.assetFileName)' should keep expected color profile behavior.")
            #expect(originalEmbeddedProfile == nil, "Original image for '\(testCase.assetFileName)' should not contain embedded ICC profile after upload.")
            #expect(smallEmbeddedProfile == nil, "Small image for '\(testCase.assetFileName)' should not contain embedded ICC profile after upload.")
        }
        
        @Test
        func `Attachment should not be uploaded when not authorized user tries to upload`() async throws {
            
            // Arrange.
            let path = application.directory.workingDirectory
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Attachment should not be uploaded when file is not provided`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rafaelexal")
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "rafaelexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "missingImage", "Error code should be equal 'missingImage'.")
        }
        
        @Test
        func `Attachment should not be saved when user email is not verified`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robikexal", emailWasConfirmed: false)
            
            let path = application.directory.workingDirectory
            let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robikexal", password: "p@ssword"),
                to: "/attachments",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "emailNotVerified", "Error code should be equal 'emailNotVerified'.")
        }

    }
}
