//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class UsersUpdateActionTests: CustomTestCase {
    
    func testAccountShouldBeUpdatedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "nickperry")
        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              baseAddress: "http://localhost:8080")

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "nickperry", password: "p@ssword"),
            to: "/users/@nickperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(updatedUserDto.id, user.stringId(), "Property 'user' should not be changed.")
        XCTAssertEqual(updatedUserDto.userName, user.userName, "Property 'userName' should not be changed.")
        XCTAssertEqual(updatedUserDto.account, user.account, "Property 'account' should not be changed.")
        XCTAssertEqual(updatedUserDto.email, user.email, "Property 'email' should not be changed.")
        XCTAssertEqual(updatedUserDto.name, userDto.name, "Property 'name' should be changed.")
        XCTAssertEqual(updatedUserDto.bio, userDto.bio, "Property 'bio' should be changed.")
    }
    
    func testFlexiFieldShouldBeAddedToExistingAccount() async throws {

        // Arrange.
        _ = try await User.create(userName: "felixperry")
        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              fields: [ FlexiFieldDto(key: "KEY", value: "VALUE", baseAddress: "http://localhost:8000") ],
                              baseAddress: "http://localhost:8000"
        )

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "felixperry", password: "p@ssword"),
            to: "/users/@felixperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertNotNil(updatedUserDto.fields?.first?.key, "Added key cannot be nil")
        XCTAssertNotNil(updatedUserDto.fields?.first?.value, "Added value cannot be nil")
        XCTAssertEqual(updatedUserDto.fields?.first?.key, "KEY", "Flexi field should be added with correct key.")
        XCTAssertEqual(updatedUserDto.fields?.first?.value, "VALUE", "Flexi field should be added with correct value.")
    }

    func testFlexiFieldShouldBeUpdatedInExistingAccount() async throws {

        // Arrange.
        let user = try await User.create(userName: "fishperry")
        _ = try await FlexiField.create(key: "KEY", value: "VALUE-A", isVerified: true, userId: user.requireID())
        
        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              fields: [ FlexiFieldDto(key: "KEY", value: "VALUE-B", baseAddress: "http://localhost:8000") ],
                              baseAddress: "http://localhost:8000"
        )

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "fishperry", password: "p@ssword"),
            to: "/users/@fishperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(updatedUserDto.fields?.count, 1, "One field should be saved in user.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.key, "Added key cannot be nil.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.value, "Added value cannot be nil.")
        XCTAssertEqual(updatedUserDto.fields?.first?.key, "KEY", "Flexi field should be added with correct key.")
        XCTAssertEqual(updatedUserDto.fields?.first?.value, "VALUE-B", "Flexi field should be added with correct value.")
    }
    
    func testFlexiFieldShouldBeUpdatedAndAddedInExistingAccount() async throws {

        // Arrange.
        let user = try await User.create(userName: "rickyperry")
        let flexiField = try await FlexiField.create(key: "KEY-A", value: "VALUE-A", isVerified: true, userId: user.requireID())
        
        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              fields: [
                                FlexiFieldDto(id: flexiField.stringId(), key: "KEY-A", value: "VALUE-B", baseAddress: "http://localhost:8000"),
                                FlexiFieldDto(id: "0", key: "KEY-B", value: "VALUE-C", baseAddress: "http://localhost:8000")
                              ],
                              baseAddress: "http://localhost:8000"
        )

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "rickyperry", password: "p@ssword"),
            to: "/users/@rickyperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(updatedUserDto.fields?.count, 2, "One field should be saved in user.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.key, "Added key cannot be nil.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.value, "Added value cannot be nil.")
        XCTAssertNotNil(updatedUserDto.fields?.last?.key, "Added key cannot be nil.")
        XCTAssertNotNil(updatedUserDto.fields?.last?.value, "Added value cannot be nil.")
        XCTAssertEqual(updatedUserDto.fields?.first?.key, "KEY-A", "Flexi field should be added with correct key.")
        XCTAssertEqual(updatedUserDto.fields?.first?.value, "VALUE-B", "Flexi field should be added with correct value.")
        XCTAssertEqual(updatedUserDto.fields?.last?.key, "KEY-B", "Flexi field should be added with correct key.")
        XCTAssertEqual(updatedUserDto.fields?.last?.value, "VALUE-C", "Flexi field should be added with correct value.")
    }
    
    func testFlexiFieldShouldBeDeletedAndAddedInExistingAccount() async throws {

        // Arrange.
        let user = try await User.create(userName: "monthyperry")
        _ = try await FlexiField.create(key: "KEY-A", value: "VALUE-A", isVerified: true, userId: user.requireID())
        
        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              fields: [
                                FlexiFieldDto(id: "0", key: "KEY-B", value: "VALUE-C", baseAddress: "http://localhost:8000")
                              ],
                              baseAddress: "http://localhost:8000"
        )

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "monthyperry", password: "p@ssword"),
            to: "/users/@monthyperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(updatedUserDto.fields?.count, 1, "One field should be saved in user.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.key, "Added key cannot be nil.")
        XCTAssertNotNil(updatedUserDto.fields?.first?.value, "Added value cannot be nil.")
        XCTAssertEqual(updatedUserDto.fields?.first?.key, "KEY-B", "Flexi field should be added with correct key.")
        XCTAssertEqual(updatedUserDto.fields?.first?.value, "VALUE-C", "Flexi field should be added with correct value.")
    }
    
    func testAccountShouldNotBeUpdatedIfUserIsNotAuthorized() async throws {

        // Arrange.
        _ = try await User.create(userName: "josepfperry")

        let userDto = UserDto(isLocal: true,
                              userName: "user name should not be changed",
                              account: "account name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              baseAddress: "http://localhost:8000")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/users/@josepfperry", method: .PUT, body: userDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    func testAccountShouldNotUpdatedWhenUserTriesToUpdateNotHisAccount() async throws {

        // Arrange.
        _ = try await User.create(userName: "georgeperry")
        _ = try await User.create(userName: "xavierperry")
        let userDto = UserDto(isLocal: true,
                              userName: "xavierperry",
                              account: "xavierperry@host.com",
                              email: "xavierperry@testemail.com",
                              name: "Xavier Perry",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              baseAddress: "http://localhost:8000")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "georgeperry", password: "p@ssword"),
            to: "/users/@xavierperry",
            method: .PUT,
            body: userDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testAccountShouldNotBeUpdatedIfNameIsTooLong() async throws {

        // Arrange.
        _ = try await User.create(userName: "brianperry")
        let userDto = UserDto(isLocal: true,
                              userName: "brianperry",
                              account: "brianperry@host.com",
                              email: "gregsmith@testemail.com",
                              name: "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901",
                              statusesCount: 0,
                              followersCount: 0,
                              followingCount: 0,
                              emailWasConfirmed: true,
                              baseAddress: "http://localhost:8000")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "brianperry", password: "p@ssword"),
            to: "/users/@brianperry",
            method: .PUT,
            data: userDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("name"), "is greater than maximum of 100 character(s) and is not null")
    }

    func testAccountShouldNotBeUpdatedIfBioIsTooLong() async throws {

        // Arrange.
        _ = try await User.create(userName: "francisperry")
        let userDto = UserDto(isLocal: true,
                              userName: "francisperry",
                              account: "francisperry@host.com",
                              email: "gregsmith@testemail.com",
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
                              emailWasConfirmed: true,
                              baseAddress: "http://localhost:8000")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "francisperry", password: "p@ssword"),
            to: "/users/@francisperry",
            method: .PUT,
            data: userDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("bio"), "is greater than maximum of 500 character(s) and is not null")
    }
}
