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

extension UsersControllerTests {
    
    @Suite("PUT /:username", .serialized, .tags(.users))
    struct UsersUpdateActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Account should be updated for authorized user")
        func accountShouldBeUpdatedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "nickperry")
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  baseAddress: "http://localhost:8080")
            
            // Act.
            let updatedUserDto = try application.getResponse(
                as: .user(userName: "nickperry", password: "p@ssword"),
                to: "/users/@nickperry",
                method: .PUT,
                data: userDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(updatedUserDto.id == user.stringId(), "Property 'user' should not be changed.")
            #expect(updatedUserDto.userName == user.userName, "Property 'userName' should not be changed.")
            #expect(updatedUserDto.account == user.account, "Property 'account' should not be changed.")
            #expect(updatedUserDto.email == user.email, "Property 'email' should not be changed.")
            #expect(updatedUserDto.name == userDto.name, "Property 'name' should be changed.")
            #expect(updatedUserDto.bio == userDto.bio, "Property 'bio' should be changed.")
        }
        
        @Test("Flexi field should be added to existing account")
        func flexiFieldShouldBeAddedToExistingAccount() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "felixperry")
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  fields: [ FlexiFieldDto(key: "KEY", value: "VALUE", baseAddress: "http://localhost:8080") ],
                                  baseAddress: "http://localhost:8080"
            )
            
            // Act.
            let updatedUserDto = try application.getResponse(
                as: .user(userName: "felixperry", password: "p@ssword"),
                to: "/users/@felixperry",
                method: .PUT,
                data: userDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(updatedUserDto.fields?.first?.key != nil, "Added key cannot be nil")
            #expect(updatedUserDto.fields?.first?.value != nil, "Added value cannot be nil")
            #expect(updatedUserDto.fields?.first?.key == "KEY", "Flexi field should be added with correct key.")
            #expect(updatedUserDto.fields?.first?.value == "VALUE", "Flexi field should be added with correct value.")
        }
        
        @Test("Flexi field should be updated in existing account")
        func flexiFieldShouldBeUpdatedInExistingAccount() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "fishperry")
            _ = try await application.createFlexiField(key: "KEY", value: "VALUE-A", isVerified: true, userId: user.requireID())
            
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  fields: [ FlexiFieldDto(key: "KEY", value: "VALUE-B", baseAddress: "http://localhost:8080") ],
                                  baseAddress: "http://localhost:8080"
            )
            
            // Act.
            let updatedUserDto = try application.getResponse(
                as: .user(userName: "fishperry", password: "p@ssword"),
                to: "/users/@fishperry",
                method: .PUT,
                data: userDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(updatedUserDto.fields?.count == 1, "One field should be saved in user.")
            #expect(updatedUserDto.fields?.first?.key != nil, "Added key cannot be nil.")
            #expect(updatedUserDto.fields?.first?.value != nil, "Added value cannot be nil.")
            #expect(updatedUserDto.fields?.first?.key == "KEY", "Flexi field should be added with correct key.")
            #expect(updatedUserDto.fields?.first?.value == "VALUE-B", "Flexi field should be added with correct value.")
        }
        
        @Test("Flexi field should be updated and added in existing account")
        func flexiFieldShouldBeUpdatedAndAddedInExistingAccount() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rickyperry")
            let flexiField = try await application.createFlexiField(key: "KEY-A", value: "VALUE-A", isVerified: true, userId: user.requireID())
            
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  fields: [
                                    FlexiFieldDto(id: flexiField.stringId(), key: "KEY-A", value: "VALUE-B", baseAddress: "http://localhost:8080"),
                                    FlexiFieldDto(id: "0", key: "KEY-B", value: "VALUE-C", baseAddress: "http://localhost:8080")
                                  ],
                                  baseAddress: "http://localhost:8080"
            )
            
            // Act.
            let updatedUserDto = try application.getResponse(
                as: .user(userName: "rickyperry", password: "p@ssword"),
                to: "/users/@rickyperry",
                method: .PUT,
                data: userDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(updatedUserDto.fields?.count == 2, "One field should be saved in user.")
            #expect(updatedUserDto.fields?.first?.key != nil, "Added key cannot be nil.")
            #expect(updatedUserDto.fields?.first?.value != nil, "Added value cannot be nil.")
            #expect(updatedUserDto.fields?.last?.key != nil, "Added key cannot be nil.")
            #expect(updatedUserDto.fields?.last?.value != nil, "Added value cannot be nil.")
            #expect(updatedUserDto.fields?.first?.key == "KEY-A", "Flexi field should be added with correct key.")
            #expect(updatedUserDto.fields?.first?.value == "VALUE-B", "Flexi field should be added with correct value.")
            #expect(updatedUserDto.fields?.last?.key == "KEY-B", "Flexi field should be added with correct key.")
            #expect(updatedUserDto.fields?.last?.value == "VALUE-C", "Flexi field should be added with correct value.")
        }
        
        @Test("Flexi field should be deleted and added in existing account")
        func flexiFieldShouldBeDeletedAndAddedInExistingAccount() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "monthyperry")
            _ = try await application.createFlexiField(key: "KEY-A", value: "VALUE-A", isVerified: true, userId: user.requireID())
            
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  fields: [
                                    FlexiFieldDto(id: "0", key: "KEY-B", value: "VALUE-C", baseAddress: "http://localhost:8080")
                                  ],
                                  baseAddress: "http://localhost:8080"
            )
            
            // Act.
            let updatedUserDto = try application.getResponse(
                as: .user(userName: "monthyperry", password: "p@ssword"),
                to: "/users/@monthyperry",
                method: .PUT,
                data: userDto,
                decodeTo: UserDto.self
            )
            
            // Assert.
            #expect(updatedUserDto.fields?.count == 1, "One field should be saved in user.")
            #expect(updatedUserDto.fields?.first?.key != nil, "Added key cannot be nil.")
            #expect(updatedUserDto.fields?.first?.value != nil, "Added value cannot be nil.")
            #expect(updatedUserDto.fields?.first?.key == "KEY-B", "Flexi field should be added with correct key.")
            #expect(updatedUserDto.fields?.first?.value == "VALUE-C", "Flexi field should be added with correct value.")
        }
        
        @Test("Account should not be updated if user is not authorized")
        func accountShouldNotBeUpdatedIfUserIsNotAuthorized() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "josepfperry")
            
            let userDto = UserDto(isLocal: true,
                                  userName: "user name should not be changed",
                                  account: "account name should not be changed",
                                  name: "Nick Perry-Fear",
                                  bio: "Architect in most innovative company.",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  baseAddress: "http://localhost:8080")
            
            // Act.
            let response = try application
                .sendRequest(to: "/users/@josepfperry", method: .PUT, body: userDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Account should not updated when user tries to update not his account")
        func accountShouldNotUpdatedWhenUserTriesToUpdateNotHisAccount() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "georgeperry")
            _ = try await application.createUser(userName: "xavierperry")
            let userDto = UserDto(isLocal: true,
                                  userName: "xavierperry",
                                  account: "xavierperry@host.com",
                                  name: "Xavier Perry",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  baseAddress: "http://localhost:8080")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "georgeperry", password: "p@ssword"),
                to: "/users/@xavierperry",
                method: .PUT,
                body: userDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Account should not be updated if name is too long")
        func accountShouldNotBeUpdatedIfNameIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "brianperry")
            let userDto = UserDto(isLocal: true,
                                  userName: "brianperry",
                                  account: "brianperry@host.com",
                                  name: "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  baseAddress: "http://localhost:8080")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "brianperry", password: "p@ssword"),
                to: "/users/@brianperry",
                method: .PUT,
                data: userDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'userAccountIsBlocked'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is greater than maximum of 100 character(s) and is not null")
        }
        
        @Test("Account should not be updated if bio is too long")
        func accountShouldNotBeUpdatedIfBioIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "francisperry")
            let userDto = UserDto(isLocal: true,
                                  userName: "francisperry",
                                  account: "francisperry@host.com",
                                  name: "Chris Perry",
                                  bio: "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "12345678901234567890123456789012345678901234567890" +
                                  "123456789012345678901234567890123456789012345678901",
                                  statusesCount: 0,
                                  followersCount: 0,
                                  followingCount: 0,
                                  baseAddress: "http://localhost:8080")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "francisperry", password: "p@ssword"),
                to: "/users/@francisperry",
                method: .PUT,
                data: userDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'userAccountIsBlocked'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("bio") == "is greater than maximum of 500 character(s) and is not null")
        }
    }
}
