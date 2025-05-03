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
    
    @Suite("BusinessCards (PUT /business-cards)", .serialized, .tags(.businessCards))
    struct BusinessCardsUpdateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Business card should be updated by authorized user")
        func businessCardShouldBeUpdatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "laratrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title laratrupnox",
                                                  subtitle: "Subtitle laratrupnox",
                                                  body: "Body laratrupnox",
                                                  website: "http://website.com",
                                                  telephone: "+48666777888",
                                                  email: "laratrupnox@test.cox",
                                                  color1: "#00FF00",
                                                  color2: "#00FF11",
                                                  color3: "#00AABB")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "laratrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                body: businessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (201).")
            let businessCard = try await application.getBusinessCard(userId: user.requireID())
            #expect(businessCard?.title == "Title laratrupnox", "Business card title should be saved.")
            #expect(businessCard?.subtitle == "Subtitle laratrupnox", "Business card subtitle should be saved.")
            #expect(businessCard?.body == "Body laratrupnox", "Business card body should be saved.")
            #expect(businessCard?.website == "http://website.com", "Business card website should be saved.")
            #expect(businessCard?.telephone == "+48666777888", "Business card telephone should be saved.")
            #expect(businessCard?.email == "laratrupnox@test.cox", "Business card email should be saved.")
            #expect(businessCard?.color1 == "#00FF00", "Business card color1 should be saved.")
            #expect(businessCard?.color2 == "#00FF11", "Business card color2 should be saved.")
            #expect(businessCard?.color3 == "#00AABB", "Business card color3 should be saved.")
        }
        
        @Test("Business card should not be updated if title was not specified")
        func businessCardShouldNotBeUpdatedIfTitleWasNotSpecified() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nikotrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "", color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "nikotrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is less than minimum of 1 character(s)")
        }
        
        @Test("Business card should not be updated if title is too long")
        func businessCardShouldNotBeUpdatedIfTitleIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robtrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: String.createRandomString(length: 201), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "robtrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("title") == "is greater than maximum of 200 character(s)")
        }
        
        @Test("Business card should not be updated if subtitle is too long")
        func businessCardShouldNotBeUpdatedIfSubtitleIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "adkatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", subtitle: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "adkatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("subtitle") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be updated if website is too long")
        func businessCardShouldNotBeUpdatedIfWebsiteIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "madziatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", website: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "madziatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("website") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be updated if telephone is too long")
        func businessCardShouldNotBeUpdatedIfTelephoneIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "idatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", telephone: String.createRandomString(length: 51), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "idatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("telephone") == "is greater than maximum of 50 character(s) and is not null")
        }
        
        @Test("Business card should not be updated if email is too long")
        func businessCardShouldNotBeUpdatedIfEmailIsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "adriantrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", email: String.createRandomString(length: 501), color1: "#000000", color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "adriantrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("email") == "is greater than maximum of 500 character(s) and is not null")
        }
        
        @Test("Business card should not be updated if color1 is too long")
        func businessCardShouldNotBeUpdatedIfColor1IsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "jolatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", color1: String.createRandomString(length: 51), color2: "#000000", color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "jolatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("color1") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("Business card should not be updated if color2 is too long")
        func businessCardShouldNotBeUpdatedIfColor2IsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "jankatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", color1: "#000000", color2: String.createRandomString(length: 51), color3: "#000000")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "jankatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
                data: businessCardDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("color2") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("Business card should not be updated if color3 is too long")
        func businessCardShouldNotBeUpdatedIfColor3IsTooLong() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "moniatrupnox")
            _ = try await application.createBusinessCard(userId: user.requireID(), title: "Title")
            let businessCardDto = BusinessCardDto(title: "Title", color1: "#000000", color2: "#000000", color3: String.createRandomString(length: 51))
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "moniatrupnox", password: "p@ssword"),
                to: "/business-cards",
                method: .PUT,
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
                method: .PUT,
                body: businessCardDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
