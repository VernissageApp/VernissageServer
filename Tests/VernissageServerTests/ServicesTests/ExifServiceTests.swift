//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

@Suite("ExifService", .serialized)
struct ExifServiceTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Camera name should use normalized make and model`() {
        #expect(ExifService.cameraName(make: " Canon ", model: " Canon EOS R5 ") == "Canon EOS R5")
        #expect(ExifService.cameraName(make: "Nikon", model: "NIKON Z f") == "Nikon Z f")
        #expect(ExifService.cameraName(make: "Leica", model: "M6") == "Leica M6")
        #expect(ExifService.cameraName(make: nil, model: "Leica M6") == "Leica M6")
        #expect(ExifService.cameraName(make: "Hasselblad", model: nil) == "Hasselblad")
        #expect(ExifService.cameraName(make: " ", model: " ") == nil)
        #expect(ExifService.nameNormalized(" Viltrox 85mm ") == "VILTROX 85MM")
        #expect(ExifService.nameNormalized(" ") == nil)
    }

    @Test
    func `Creating and updating status should synchronize Exif dictionaries relationships and amounts`() async throws {
        let user = try await application.createUser(userName: "exifservicesynchronization")
        let firstAttachment = try await application.createAttachment(
            user: user,
            make: "Runtime Camera",
            model: "Runtime Camera X1",
            lens: "Runtime Lens 50mm",
            film: "Runtime Film 400"
        )
        let secondAttachment = try await application.createAttachment(
            user: user,
            make: "RUNTIME CAMERA",
            model: "RUNTIME CAMERA X1",
            lens: "RUNTIME LENS 50MM",
            film: "RUNTIME FILM 400"
        )
        let thirdAttachment = try await application.createAttachment(
            user: user,
            make: "runtime camera",
            model: "x1",
            lens: "runtime lens 50mm",
            film: "runtime film 400"
        )

        defer {
            application.clearFiles(attachments: [firstAttachment, secondAttachment, thirdAttachment])
        }

        let status = try await application.createStatus(
            user: user,
            note: "Status used to test Exif synchronization",
            attachmentIds: [
                firstAttachment.stringId()!,
                secondAttachment.stringId()!,
                thirdAttachment.stringId()!
            ]
        )

        let camera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME CAMERA X1")
                .first()
        )
        let lens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME LENS 50MM")
                .first()
        )
        let film = try #require(
            try await Film.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME FILM 400")
                .first()
        )

        #expect(camera.name == "Runtime Camera X1")
        #expect(lens.name == "Runtime Lens 50mm")
        #expect(film.name == "Runtime Film 400")
        #expect(camera.amount == 3)
        #expect(lens.amount == 3)
        #expect(film.amount == 3)
        #expect(try await Camera.query(on: application.db).filter(\.$nameNormalized == camera.nameNormalized).count() == 1)
        #expect(try await Lens.query(on: application.db).filter(\.$nameNormalized == lens.nameNormalized).count() == 1)
        #expect(try await Film.query(on: application.db).filter(\.$nameNormalized == film.nameNormalized).count() == 1)
        #expect(
            try await CameraStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 1
        )
        #expect(
            try await LensStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 1
        )
        #expect(
            try await FilmStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 1
        )

        let updatedAttachment = try await application.createAttachment(
            user: user,
            make: "Updated Runtime Camera",
            model: "Updated Runtime Camera X2",
            lens: "Updated Runtime Lens 85mm",
            film: "Updated Runtime Film 800"
        )
        defer {
            application.clearFiles(attachments: [updatedAttachment])
        }

        let statusRequestDto = StatusRequestDto(
            note: "Updated status used to test Exif synchronization",
            visibility: .public,
            sensitive: false,
            contentWarning: nil,
            commentsDisabled: false,
            categoryId: nil,
            replyToStatusId: nil,
            attachmentIds: [updatedAttachment.stringId()!]
        )

        _ = try await application.getResponse(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .PUT,
            data: statusRequestDto,
            decodeTo: StatusDto.self
        )

        let updatedCamera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$nameNormalized == "UPDATED RUNTIME CAMERA X2")
                .first()
        )
        let updatedLens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$nameNormalized == "UPDATED RUNTIME LENS 85MM")
                .first()
        )
        let updatedFilm = try #require(
            try await Film.query(on: application.db)
                .filter(\.$nameNormalized == "UPDATED RUNTIME FILM 800")
                .first()
        )

        let previousCamera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME CAMERA X1")
                .first()
        )
        let previousLens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME LENS 50MM")
                .first()
        )
        let previousFilm = try #require(
            try await Film.query(on: application.db)
                .filter(\.$nameNormalized == "RUNTIME FILM 400")
                .first()
        )

        #expect(previousCamera.amount == 0)
        #expect(previousLens.amount == 0)
        #expect(previousFilm.amount == 0)
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
    func `Deleting status should decrement Exif amounts and remove relationships`() async throws {
        let user = try await application.createUser(userName: "exifservicedeletion")
        let attachment = try await application.createAttachment(
            user: user,
            make: "Deletion Camera",
            model: "Deletion Camera X1",
            lens: "Deletion Lens 50mm",
            film: "Deletion Film 400"
        )
        defer {
            application.clearFiles(attachments: [attachment])
        }

        let status = try await application.createStatus(
            user: user,
            note: "Status used to test Exif deletion synchronization",
            attachmentIds: [try #require(attachment.stringId())]
        )

        let camera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$nameNormalized == "DELETION CAMERA X1")
                .first()
        )
        let lens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$nameNormalized == "DELETION LENS 50MM")
                .first()
        )
        let film = try #require(
            try await Film.query(on: application.db)
                .filter(\.$nameNormalized == "DELETION FILM 400")
                .first()
        )

        #expect(camera.amount == 1)
        #expect(lens.amount == 1)
        #expect(film.amount == 1)

        let response = try await application.sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/statuses/\(status.requireID())",
            method: .DELETE
        )

        #expect(response.status == .ok)

        let updatedCamera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$id == camera.requireID())
                .first()
        )
        let updatedLens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$id == lens.requireID())
                .first()
        )
        let updatedFilm = try #require(
            try await Film.query(on: application.db)
                .filter(\.$id == film.requireID())
                .first()
        )

        #expect(updatedCamera.amount == 0)
        #expect(updatedLens.amount == 0)
        #expect(updatedFilm.amount == 0)
        #expect(
            try await CameraStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 0
        )
        #expect(
            try await LensStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 0
        )
        #expect(
            try await FilmStatus.query(on: application.db)
                .filter(\.$id.$status.$id == status.requireID())
                .count() == 0
        )
    }

    @Test
    func `Exif amounts should include only public and quiet public statuses`() async throws {
        let user = try await application.createUser(userName: "exifservicevisibility")
        var attachments: [VernissageServer.Attachment] = []

        for _ in 0..<4 {
            let attachment = try await application.createAttachment(
                user: user,
                make: "Visibility Camera",
                model: "Visibility Camera X1",
                lens: "Visibility Lens 50mm",
                film: "Visibility Film 400"
            )
            attachments.append(attachment)
        }

        defer {
            application.clearFiles(attachments: attachments)
        }

        let attachmentIds = try attachments.map { attachment in
            try #require(attachment.stringId())
        }

        _ = try await application.createStatus(
            user: user,
            note: "Public status",
            attachmentIds: [attachmentIds[0]],
            visibility: .public
        )
        _ = try await application.createStatus(
            user: user,
            note: "Quiet public status",
            attachmentIds: [attachmentIds[1]],
            visibility: .quietPublic
        )
        _ = try await application.createStatus(
            user: user,
            note: "Followers status",
            attachmentIds: [attachmentIds[2]],
            visibility: .followers
        )
        _ = try await application.createStatus(
            user: user,
            note: "Mentioned status",
            attachmentIds: [attachmentIds[3]],
            visibility: .mentioned
        )

        let camera = try #require(
            try await Camera.query(on: application.db)
                .filter(\.$nameNormalized == "VISIBILITY CAMERA X1")
                .first()
        )
        let lens = try #require(
            try await Lens.query(on: application.db)
                .filter(\.$nameNormalized == "VISIBILITY LENS 50MM")
                .first()
        )
        let film = try #require(
            try await Film.query(on: application.db)
                .filter(\.$nameNormalized == "VISIBILITY FILM 400")
                .first()
        )

        #expect(camera.amount == 2)
        #expect(lens.amount == 2)
        #expect(film.amount == 2)
    }
}
