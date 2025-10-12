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
    
    @Suite("Licenses (POST /licenses)", .serialized, .tags(.licenses))
    struct LicensesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("License should be created by administrator")
        func licenseShouldBeCreatedByAdministrator() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larazena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: "License test 0001", code: "L-0001", description: "License description 0001")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larazena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let license = try await application.getLicense(code: "L-0001")
            #expect(license?.name == "License test 0001", "Name should be set correctly.")
            #expect(license?.description == "License description 0001", "Description should be set correctly.")
        }
        
        @Test("License should not be created if name was not specified")
        func licenseShouldNotBeCreatedIfNameWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikozena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: "", code: "L-0002", description: "License description 0002")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikozena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is empty")
        }
        
        @Test("License should not be created if name is too long")
        func licenseShouldNotBeCreatedIfNameIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robotzena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: String.createRandomString(length: 101), code: "L-0003", description: "License description 0003")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robotzena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is greater than maximum of 100 character(s)")
        }
        
        @Test("License should not be created if code is too long")
        func licenseShouldNotBeCreatedIfCodeIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "annazena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: "License test 0005", code: String.createRandomString(length: 51), description: "License description 0005")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annazena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("code") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("License should not be created if description is too long")
        func licenseShouldNotBeCreatedIfDescriptionIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "mariazena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: "License test 0007", code: "L-0007", description: String.createRandomString(length: 1001))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "mariazena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                data: licenseDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("description") == "is greater than maximum of 1000 character(s)")
        }
        
        @Test("License should not be created if url is too long")
        func licenseShouldNotBeCreatedIfUrlIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "tobiaszzena")
            try await application.attach(user: user, role: Role.moderator)
            
            let licenseDto = LicenseDto(name: "License test 0008", code: "L-0008", description: "License description 0008", url: String.createRandomString(length: 501))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "tobiaszzena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
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
            _ = try await application.createUser(userName: "nogozena")
            let licenseDto = LicenseDto(name: "License test 0009", code: "L-0009", description: "License description 0009")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogozena", password: "p@ssword"),
                to: "/licenses",
                method: .POST,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorizena")
            let licenseDto = LicenseDto(name: "License test 0009", code: "L-0010", description: "License description 0010")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/licenses",
                method: .POST,
                body: licenseDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
