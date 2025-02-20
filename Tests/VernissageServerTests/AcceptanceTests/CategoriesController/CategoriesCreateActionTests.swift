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
    
    @Suite("Categories (POST /categories)", .serialized, .tags(.categories))
    struct CategoriesCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Category should be created by authorized user")
        func categoryShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laraurobix")
            try await application.attach(user: user, role: Role.moderator)
            
            let categoryDto = CategoryDto(id: nil, name: "Category 01", priority: 2, isEnabled: true, hashtags: [
                CategoryHashtagDto(hashtag: "Tag1", hashtagNormalized: ""),
                CategoryHashtagDto(hashtag: "Tag2", hashtagNormalized: "")
            ])
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "laraurobix", password: "p@ssword"),
                to: "/categories",
                method: .POST,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let category = try await application.getCategory(name: "Category 01")
            #expect(category?.nameNormalized == "CATEGORY 01", "Category normlized should be set correctly.")
        }
        
        @Test("Category should not be created if name was not specified")
        func categoryShouldNotBeCreatedIfNameWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikourobix")
            try await application.attach(user: user, role: Role.moderator)
            
            let categoryDto = CategoryDto(id: nil, name: "", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "nikourobix", password: "p@ssword"),
                to: "/categories",
                method: .POST,
                data: categoryDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Category should not be created if name is too long")
        func instanceBlockedDomainShouldNotBeCreatedIfDomainIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "roboturobix")
            try await application.attach(user: user, role: Role.moderator)
            
            let categoryDto = CategoryDto(id: nil, name: String.createRandomString(length: 101), priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "roboturobix", password: "p@ssword"),
                to: "/categories",
                method: .POST,
                data: categoryDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is greater than maximum of 100 character(s)")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogourobix")
            let categoryDto = CategoryDto(id: nil, name: "Category 02", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "nogourobix", password: "p@ssword"),
                to: "/categories",
                method: .POST,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let categoryDto = CategoryDto(id: nil, name: "Category 03", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let response = try application.sendRequest(
                to: "/categories",
                method: .POST,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
