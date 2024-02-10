//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Attachment {
    static func get(userId: Int64) async throws -> Attachment {
        guard let attachment = try await Attachment.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == userId)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$location)
            .with(\.$license)
            .with(\.$exif)
            .first() else {
            throw SharedApplicationError.unwrap
        }

        return attachment
    }
    
    static func create(user: User) async throws -> Attachment {
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/attachments",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        guard let attachment = try await Attachment.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$location)
            .with(\.$exif)
            .with(\.$license)
            .sort(\.$createdAt, .descending)
            .first() else {
            throw SharedApplicationError.unwrap
        }
        
        let location = try await Location.create(name: "Legnica")
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
                                                            locationId: location.stringId())
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/attachments/\(attachment.stringId() ?? "")",
            method: .PUT,
            body: temporaryAttachmentDto
        )
        
        return attachment
    }
}
