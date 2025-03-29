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
    
    @Suite("UserAliases (POST /user-aliases)", .serialized, .tags(.userAliases))
    struct UserAliasesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User alias should be created by authorized user")
        func userAliasShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "laraubionix")
            let userAliasDto = UserAliasDto(alias: "laraubionix@alias.com")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laraubionix", password: "p@ssword"),
                to: "/user-aliases",
                method: .POST,
                body: userAliasDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let userAlias = try await application.getUserAlias(alias: "laraubionix@alias.com")
            #expect(userAlias?.aliasNormalized == "LARAUBIONIX@ALIAS.COM", "Normalized alias shoud be set correctly.")
        }
        
        @Test("User alias should not be created if alias was not specified")
        func userAliasShouldNotBeCreatedIfAliasWasNotSpecified() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "georgeubionix")
            let userAliasDto = UserAliasDto(alias: "")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "georgeubionix", password: "p@ssword"),
                to: "/user-aliases",
                method: .POST,
                data: userAliasDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("alias") == "is empty")
        }
        
        @Test("User alias should not be created if alias is too long")
        func userAliasShouldNotBeCreatedIfAliasIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "michaelubionix")
            let userAliasDto = UserAliasDto(alias: String.createRandomString(length: 101))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "michaelubionix", password: "p@ssword"),
                to: "/user-aliases",
                method: .POST,
                data: userAliasDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("alias") == "is greater than maximum of 100 character(s)")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let userAliasDto = UserAliasDto(alias: "rickiubionix@alias.com")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/user-aliases",
                method: .POST,
                body: userAliasDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
