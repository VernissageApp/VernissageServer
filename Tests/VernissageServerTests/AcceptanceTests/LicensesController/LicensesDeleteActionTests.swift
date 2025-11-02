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
    
    @Suite("Licenses (DELETE /licenses/:id)", .serialized, .tags(.licenses))
    struct LicensesDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `License should be deleted by authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "lararebio")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 2001",code: "L-2001", description: "License description 2001", url: nil)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "lararebio", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let license = try await application.getLicense(code: "L-2001")
            #expect(license == nil, "License should be deleted.")
        }

        @Test
        func `Forbidden should be returned for already used license`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "renerebio")
            try await application.attach(user: user, role: Role.moderator)
            let orginalLicense = try await application.createLicense(name: "License test 2002",code: "L-2002", description: "License description 2002", url: nil)
            
            let attachment = try await application.createAttachment(user: user, licenseId: orginalLicense.stringId())
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "renerebio", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogorebio")
            let orginalLicense = try await application.createLicense(name: "License test 2003",code: "L-2003", description: "License description 2003", url: nil)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogorebio", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test
        func `Unauthorize should be returned for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorigrobio")
            let orginalLicense = try await application.createLicense(name: "License test 2004",code: "L-2004", description: "License description 2004", url: nil)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
