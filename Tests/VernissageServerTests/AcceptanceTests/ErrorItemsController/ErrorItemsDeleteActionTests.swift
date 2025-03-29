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
    
    @Suite("ErrorItems (DELETE /error-items/:id)", .serialized, .tags(.rules))
    struct ErrorItemsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Error item should be deleted by authorized user")
        func errorItemShouldBeDeletedByAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "lararono")
            try await application.attach(user: user, role: Role.moderator)
            let orginalErrorItem = try await application.createErrorItem(message: "This is error message!")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "lararono", password: "p@ssword"),
                to: "/error-items/" + (orginalErrorItem.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be created (200).")
            let errorItem = try await application.getErrorItem(code: orginalErrorItem.code)
            #expect(errorItem == nil, "Error item should be deleted.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeReturneddForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nogorono")
            let orginalErrorItem = try await application.createErrorItem(message: "This is error message!")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "nogorono", password: "p@ssword"),
                to: "/error-items/" + (orginalErrorItem.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be unauthoroized (403).")
        }
        
        @Test("Unauthorize should be returned for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorirono")
            let orginalErrorItem = try await application.createErrorItem(message: "This is error message!")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/error-items/" + (orginalErrorItem.stringId() ?? ""),
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
