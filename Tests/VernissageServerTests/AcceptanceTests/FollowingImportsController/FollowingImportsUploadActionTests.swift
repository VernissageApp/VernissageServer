//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("FollowingImports (POST /following-imports)", .serialized, .tags(.followingImports))
    struct FollowingImportsUploadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Following import file should be upladed and parsed for correct file and authorized user")
        func followingImportFileShouldBeUploadedAndParsedForCorrectFileAndAuthorizedUser() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "georgedash")
            
            let path = FileManager.default.currentDirectoryPath
            let csvFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/following.csv"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "following.csv", data: csvFile, mimeType: "text/csv")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "georgedash", password: "p@ssword"),
                to: "/following-imports",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

            let followingImports = try await application.getFollowingImports(userId: user.requireID())
            #expect(followingImports.count == 1, "Following import should be saved into database")
            #expect(followingImports.first?.followingImportItems.count == 3, "Following import accounts should be saved into database")
        }
        
        @Test("Following import file should not be uploaded when not authorized user tries to upload")
        func followingImportFileShouldNotBeUploadedWhenNotAuthorizedUserTriesToUpload() async throws {
            
            // Arrange.
            let path = FileManager.default.currentDirectoryPath
            let csvFile = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Tests/VernissageServerTests/Assets/following.csv"))
            
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            formDataBuilder.addDataField(named: "file", fileName: "following.csv", data: csvFile, mimeType: "text/csv")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/following-imports",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Following import file should not be uploaded when file is not provided")
        func followingImportFileShouldNotBeUploadedWhenFileIsNotProvided() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annadash")
            let formDataBuilder = MultipartFormData(boundary: String.createRandomString(length: 10))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annadash", password: "p@ssword"),
                to: "/following-imports",
                method: .POST,
                headers: .init([("content-type", "multipart/form-data; boundary=\(formDataBuilder.boundary)")]),
                body: formDataBuilder.build()
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "missingFile", "Error code should be equal 'missingFile'.")
        }
    }
}
