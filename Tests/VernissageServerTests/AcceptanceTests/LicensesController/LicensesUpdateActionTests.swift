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
    
    @Suite("Licenses (PUT /licenses/:id)", .serialized, .tags(.licenses))
    struct LicensesUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("License should be updated by administrator")
        func licenseShouldBeUpdatedByAdministrator() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larazenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1001",code: "L-1001", description: "License description 1001", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License changed 1001", code: "X-1001", description: "License description changed 1001", url: "https://changes.url/")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larazenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let license = try await application.getLicense(code: "X-1001")
            #expect(license?.name == "License changed 1001", "Name should be set correctly.")
            #expect(license?.description == "License description changed 1001", "Description should be set correctly.")
            #expect(license?.url == "https://changes.url/", "Url should be set correctly.")
        }
        
        @Test("License should not be updated if name was not specified")
        func licenseShouldNotBeUpdatedIfNameWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikozenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1002", code: "L-1002", description: "License description 1002", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "", code: "L-1002", description: "License description 1002")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikozenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is empty")
        }
        
        @Test("License should not be updated if name is too long")
        func licenseShouldNotBeUpdatedIfNameIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robotzenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1003", code: "L-1003", description: "License description 1003", url: "https://url.com/")
            let licenseDto = LicenseDto(name: String.createRandomString(length: 101), code: "L-1003", description: "License description 1003")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robotzenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is greater than maximum of 100 character(s)")
        }
        
        @Test("License should not be updated if code is too long")
        func licenseShouldNotBeUpdatedIfCodeIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annazenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1005", code: "L-1005", description: "License description 1005", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License test 1005", code: String.createRandomString(length: 51), description: "License description 1005")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annazenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("code") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("License should not be updated if description is too long")
        func licenseShouldNotBeUpdatedIfDescriptionIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "mariazenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1007", code: "L-1007", description: "License description 1007", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License test 1007", code: "L-1007", description: String.createRandomString(length: 1001))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "mariazenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("description") == "is greater than maximum of 1000 character(s)")
        }
        
        @Test("License should not be updated if url is too long")
        func licenseShouldNotBeUpdatedIfUrlIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tobiaszzenx")
            try await application.attach(user: user, role: Role.moderator)
            
            let orginalLicense = try await application.createLicense(name: "License test 1008", code: "L-1008", description: "License description 1008", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License test 1008", code: "L-1008", description: "License description 1008", url: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "tobiaszzenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("url") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Forbidden should be returnedd for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogozenx")
            let orginalLicense = try await application.createLicense(name: "License test 1009", code: "L-1009", description: "License description 1009", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License test 1009", code: "L-1009", description: "License description 1009")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogozenx", password: "p@ssword"),
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorizenx")
            let orginalLicense = try await application.createLicense(name: "License test 1010", code: "L-1010", description: "License description 1010", url: "https://url.com/")
            let licenseDto = LicenseDto(name: "License test 1010", code: "L-1010", description: "License description 1010")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/licenses/" + (orginalLicense.stringId() ?? ""),
                method: .PUT,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
