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
    
    @Suite("Categories (PUT /categories/:id)", .serialized, .tags(.categories))
    struct CategoriesUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Category should be updated by authorized user")
        func categoryShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laravikix")
            try await application.attach(user: user, role: Role.moderator)
            
            let category = try await application.getCategory(name: "Nude")
            
            let categoryDto = CategoryDto(id: category?.stringId(), name: "Golizna", priority: 10, isEnabled: false, hashtags: [
                CategoryHashtagDto(hashtag: "nagosc", hashtagNormalized: ""),
                CategoryHashtagDto(hashtag: "tylek", hashtagNormalized: "")
            ])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laravikix", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .PUT,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let categoryAfterUpdate = try await application.getCategory(name: "Golizna")
            #expect(categoryAfterUpdate?.nameNormalized == "GOLIZNA", "Name should be set correctly.")
            #expect(categoryAfterUpdate?.priority == 10, "Correct priority should be set.")
            #expect(categoryAfterUpdate?.isEnabled == false, "Is enabled should be set to false.")
            #expect(categoryAfterUpdate?.hashtags.count == 2, "Two hashtags should be connected with category.")
            #expect(categoryAfterUpdate?.hashtags.contains(where: { $0.hashtag == "nagosc" }) == true, "Nagosc tag should be set correctly.")
            #expect(categoryAfterUpdate?.hashtags.contains(where: { $0.hashtag == "tylek" }) == true, "Tylek tag should be set correctly.")
        }
        
        @Test("Category should not be updated if name was not specified")
        func categoryShouldNotBeUpdatedIfNameWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikovikix")
            try await application.attach(user: user, role: Role.moderator)
            
            let category = try await application.getCategory(name: "Travel")
            let categoryDto = CategoryDto(id: category?.stringId(), name: "", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikovikix", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .PUT,
                data: categoryDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Category should not be updated if name is too long")
        func categoryShouldNotBeUpdatedIfDomainIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robotvikix")
            try await application.attach(user: user, role: Role.moderator)
            
            let category = try await application.getCategory(name: "Travel")
            let categoryDto = CategoryDto(id: category?.stringId(), name: String.createRandomString(length: 101), priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robotvikix", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .PUT,
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
            _ = try await application.createUser(userName: "nogovikix")
            let category = try await application.getCategory(name: "Travel")
            let categoryDto = CategoryDto(id: category?.stringId(), name: "Category 02", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogovikix", password: "p@ssword"),
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .PUT,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let category = try await application.getCategory(name: "Travel")
            let categoryDto = CategoryDto(id: category?.stringId(), name: "Category 03", priority: 2, isEnabled: true, hashtags: [])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/categories/" + (category?.stringId() ?? ""),
                method: .PUT,
                body: categoryDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
