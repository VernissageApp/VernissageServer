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
    
    @Suite("BusinessCards (POST /business-cards)", .serialized, .tags(.businessCards))
    struct BusinessCardsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Business card should be created by authorized user")
        func businessCardShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "larabedox")
            let businessCardDto = BusinessCardDto(title: "Title larabedox",
                                                  subtitle: "Subtitle larabedox",
                                                  body: "Body larabedox",
                                                  website: "http://website.com",
                                                  telephone: "+48666777888",
                                                  email: "larabedox@test.cox",
                                                  color1: "#00FF00",
                                                  color2: "#00FF11",
                                                  color3: "#00AABB")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "larabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                body: businessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let businessCard = try await application.getBusinessCard(userId: user.requireID())
            #expect(businessCard?.title == "Title larabedox", "Business card title should be saved.")
            #expect(businessCard?.subtitle == "Subtitle larabedox", "Business card subtitle should be saved.")
            #expect(businessCard?.body == "Body larabedox", "Business card body should be saved.")
            #expect(businessCard?.website == "http://website.com", "Business card website should be saved.")
            #expect(businessCard?.telephone == "+48666777888", "Business card telephone should be saved.")
            #expect(businessCard?.email == "larabedox@test.cox", "Business card email should be saved.")
            #expect(businessCard?.color1 == "#00FF00", "Business card color1 should be saved.")
            #expect(businessCard?.color2 == "#00FF11", "Business card color2 should be saved.")
            #expect(businessCard?.color3 == "#00AABB", "Business card color3 should be saved.")
        }
        
        @Test("Business card should not be created when already exists")
        func businessCardShouldNotBeCreatedWhenAlreadyExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "hindibedox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            
            let businessCardDto = BusinessCardDto(title: "Title hindibedox",
                                                  subtitle: "Subtitle hindibedox",
                                                  body: "Body hindibedox",
                                                  website: "http://website.com",
                                                  telephone: "+48666777888",
                                                  email: "hindibedox@test.cox",
                                                  color1: "#00FF00",
                                                  color2: "#00FF11",
                                                  color3: "#00AABB")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "hindibedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                body: businessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Business card should not be created if title was not specified")
        func businessCardShouldNotBeCreatedIfTitleWasNotSpecified() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nikobedox")
            let businessCardDto = BusinessCardDto(title: "", color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikobedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Business card should not be created if title is too long")
        func businessCardShouldNotBeCreatedIfTitleIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robbedox")
            let businessCardDto = BusinessCardDto(title: String.createRandomString(length: 201), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robbedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s)")
        }
        
        @Test("Business card should not be created if subtitle is too long")
        func businessCardShouldNotBeCreatedIfSubtitleIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "adkabedox")
            let businessCardDto = BusinessCardDto(title: "Title", subtitle: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "adkabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("subtitle") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be created if website is too long")
        func businessCardShouldNotBeCreatedIfWebsiteIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "madziabedox")
            let businessCardDto = BusinessCardDto(title: "Title", website: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "madziabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("website") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be created if telephone is too long")
        func businessCardShouldNotBeCreatedIfTelephoneIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "idabedox")
            let businessCardDto = BusinessCardDto(title: "Title", telephone: String.createRandomString(length: 51), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "idabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("telephone") == "is greater than maximum of 50 character(s) and is not null")
        }
        
        @Test("Business card should not be created if email is too long")
        func businessCardShouldNotBeCreatedIfEmailIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "adrianbedox")
            let businessCardDto = BusinessCardDto(title: "Title", email: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "adrianbedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("email") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be created if color1 is too long")
        func businessCardShouldNotBeCreatedIfColor1IsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "jolabedox")
            let businessCardDto = BusinessCardDto(title: "Title", color1: String.createRandomString(length: 51), color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "jolabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("color1") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("Business card should not be created if color2 is too long")
        func businessCardShouldNotBeCreatedIfColor2IsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "jankabedox")
            let businessCardDto = BusinessCardDto(title: "Title", color1: "#000000", color2: String.createRandomString(length: 51), color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "jankabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("color2") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("Business card should not be created if color3 is too long")
        func businessCardShouldNotBeCreatedIfColor3IsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "moniabedox")
            let businessCardDto = BusinessCardDto(title: "Title", color1: "#000000", color2: "#000000", color3: String.createRandomString(length: 51))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "moniabedox", password: "p@ssword"),
                to: "/business-cards",
                method: .POST,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("color3") == "is greater than maximum of 50 character(s)")
        }
                        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let businessCardDto = BusinessCardDto(title: "Title", color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/business-cards",
                method: .POST,
                body: businessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
