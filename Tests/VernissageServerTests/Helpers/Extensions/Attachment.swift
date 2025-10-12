//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getAttachment(userId: Int64) async throws -> Attachment {
        guard let attachment = try await Attachment.query(on: self.db)
            .filter(\.$user.$id == userId)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$originalHdrFile)
            .with(\.$location)
            .with(\.$license)
            .with(\.$exif)
            .first() else {
            throw SharedApplicationError.unwrap
        }

        return attachment
    }
    
    func createAttachment(user: User,
                          description: String? = nil,
                          blurhash: String? = nil,
                          make: String? = nil,
                          model: String? = nil,
                          lens: String? = nil,
                          createDate: String? = nil,
                          focalLenIn35mmFilm: String? = nil,
                          fNumber: String? = nil,
                          exposureTime: String? = nil,
                          photographicSensitivity: String? = nil,
                          film: String? = nil,
                          latitude: String? = nil,
                          longitude: String? = nil,
                          flash: String? = nil,
                          focalLength: String? = nil,
                          licenseId: String? = nil
    ) async throws -> Attachment {
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        let response = try await self.sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/attachments",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        print(response.body.string)
        
        guard let attachment = try await Attachment.query(on: self.db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$originalHdrFile)
            .with(\.$location)
            .with(\.$exif)
            .with(\.$license)
            .sort(\.$createdAt, .descending)
            .first() else {
            throw SharedApplicationError.unwrap
        }
        
        let location = try await self.createLocation(name: "Legnica")
        let temporaryAttachmentDto = TemporaryAttachmentDto(id: attachment.stringId(),
                                                            url: "",
                                                            previewUrl: "",
                                                            description: description ?? "This is description...",
                                                            blurhash: blurhash ?? "BLURHASH",
                                                            make: make ?? "Sony",
                                                            model: model ?? "A7IV",
                                                            lens: lens ?? "Viltrox 85",
                                                            createDate: createDate ?? "2023-07-13T20:15:35.319+02:00",
                                                            focalLenIn35mmFilm: focalLenIn35mmFilm ?? "85",
                                                            fNumber: fNumber ?? "f/1.8",
                                                            exposureTime: exposureTime ?? "1/250",
                                                            photographicSensitivity: photographicSensitivity ?? "2000",
                                                            film: film ?? "Kodak",
                                                            locationId: location.stringId(),
                                                            licenseId: licenseId,
                                                            latitude: latitude ?? "51.235722",
                                                            longitude: longitude ?? "22.562222",
                                                            flash: flash ?? "On",
                                                            focalLength: focalLength ?? "85mm")
        
        // Act.
        _ = try await self.sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            body: temporaryAttachmentDto
        )
        
        return attachment
    }
}
