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

@Suite("DELETE /:id", .serialized, .tags(.headers))
struct HeadersDeleteActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Header should be deleted for correct request")
    func headerShouldBeDeletedForCorrectRequest() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "triszero")
        
        let path = FileManager.default.currentDirectoryPath
        let imageFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/001.png"))
        
        let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
        formDataBuilder.addDataField(named: "file", fileName: "001.png", data: imageFile, mimeType: "image/png")
        
        _ = try application.sendRequest(
            as: .user(userName: "triszero", password: "p@ssword"),
            to: "/headers/@triszero",
            method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
            body: formDataBuilder.build()
        )
        
        let userAfterRequest = try await application.getUser(userName: "triszero")
        let headerFileName = userAfterRequest.headerFileName
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "triszero", password: "p@ssword"),
            to: "/headers/@triszero",
            method: .DELETE
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let userAfterDelete = try await application.getUser(userName: "triszero")
        #expect(userAfterDelete.headerFileName == nil, "Header file name should be deleted from database.")
        
        let headerFilePath = "\(FileManager.default.currentDirectoryPath)/Public/storage/\(headerFileName!)"
        #expect(FileManager.default.fileExists(atPath: headerFilePath) == false, "File should not exists on disk.")
    }
    
    @Test("Header should not be deleted when not authorized user tries to delete header")
    func headerShouldNotBeDeletedWhenNotAuthorizedUserTriesToDeleteHeader() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "romanzero")
        
        // Act.
        let response = try application.sendRequest(
            to: "/headers/@romanzero",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    @Test("Header should not be delete when different user deletes header")
    func headerShouldNotBeDeleteWhenDifferentUserDeletesHeader() async throws {
        // Arrange.
        _ = try await application.createUser(userName: "vikizero")
        _ = try await application.createUser(userName: "erikzero")
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "erikzero", password: "p@ssword"),
            to: "/headers/@vikizero",
            method: .DELETE
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
