@testable import App
import XCTest
import XCTVapor

final class UsersUpdateActionTests: XCTestCase {
    
    func testAccountShouldBeUpdatedForAuthorizedUser() throws {

        // Arrange.
        let user = try User.create(userName: "nickperry")
        let userDto = UserDto(id: UUID(),
                              userName: "user name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              location: "San Francisco",
                              website: "http://architect.com",
                              birthDate: Date(),
                              gravatarHash: "gravatarHash should not be changed")

        // Act.
        let updatedUserDto = try SharedApplication.application().getResponse(
            as: .user(userName: "nickperry", password: "p@ssword"),
            to: "/users/@nickperry",
            method: .PUT,
            data: userDto,
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(updatedUserDto.id, user.id, "Property 'user' should not be changed.")
        XCTAssertEqual(updatedUserDto.userName, user.userName, "Property 'userName' should not be changed.")
        XCTAssertEqual(updatedUserDto.email, user.email, "Property 'email' should not be changed.")
        XCTAssertEqual(updatedUserDto.gravatarHash, user.gravatarHash, "Property 'gravatarHash' should not be changed.")
        XCTAssertEqual(updatedUserDto.name, userDto.name, "Property 'name' should be changed.")
        XCTAssertEqual(updatedUserDto.bio, userDto.bio, "Property 'bio' should be changed.")
        XCTAssertEqual(updatedUserDto.location, userDto.location, "Property 'location' should be changed.")
        XCTAssertEqual(updatedUserDto.website, userDto.website, "Property 'website' should be changed.")
        XCTAssertEqual(updatedUserDto.birthDate?.description, userDto.birthDate?.description, "Property 'birthDate' should be changed.")
    }

    func testAccountShouldNotBeUpdatedIfUserIsNotAuthorized() throws {

        // Arrange.
        _ = try User.create(userName: "josepfperry")

        let userDto = UserDto(id: UUID(),
                              userName: "user name should not be changed",
                              email: "email should not be changed",
                              name: "Nick Perry-Fear",
                              bio: "Architect in most innovative company.",
                              location: "San Francisco",
                              website: "http://architect.com",
                              birthDate: Date(),
                              gravatarHash: "gravatarHash should not be changed")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/users/@josepfperry", method: .PUT, body: userDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    func testAccountShouldNotUpdatedWhenUserTriesToUpdateNotHisAccount() throws {

        // Arrange.
        _ = try User.create(userName: "georgeperry")
        _ = try User.create(userName: "xavierperry")
        let userDto = UserDto(id: UUID(), userName: "xavierperry", email: "xavierperry@testemail.com", name: "Xavier Perry")

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

    func testAccountShouldNotBeUpdatedIfNameIsTooLong() throws {

        // Arrange.
        _ = try User.create(userName: "brianperry")
        let userDto = UserDto(userName: "brianperry",
                              email: "gregsmith@testemail.com",
                              name: "123456789012345678901234567890123456789012345678901")

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
        XCTAssertEqual(errorResponse.error.failures?.getFailure("name"), "is greater than maximum of 50 character(s) and is not null")
    }

    func testAccountShouldNotBeUpdatedIfLocationIsTooLong() throws {

        // Arrange.
        _ = try User.create(userName: "chrisperry")
        let userDto = UserDto(userName: "chrisperry",
                              email: "gregsmith@testemail.com",
                              name: "Chris Perry",
                              location: "123456789012345678901234567890123456789012345678901")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "chrisperry", password: "p@ssword"),
            to: "/users/@chrisperry",
            method: .PUT,
            data: userDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("location"), "is greater than maximum of 50 character(s) and is not null")
    }

    func testAccountShouldNotBeUpdatedIfWebsiteIsTooLong() throws {

        // Arrange.
        _ = try User.create(userName: "lukeperry")
        let userDto = UserDto(userName: "lukeperry",
                              email: "gregsmith@testemail.com",
                              name: "Chris Perry",
                              website: "123456789012345678901234567890123456789012345678901")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "lukeperry", password: "p@ssword"),
            to: "/users/@lukeperry",
            method: .PUT,
            data: userDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("website"), "is greater than maximum of 50 character(s) and is not null")
    }

    func testAccountShouldNotBeUpdatedIfBioIsTooLong() throws {

        // Arrange.
        _ = try User.create(userName: "francisperry")
        let userDto = UserDto(userName: "francisperry",
                              email: "gregsmith@testemail.com",
                              name: "Chris Perry",
                              bio: "12345678901234567890123456789012345678901234567890" +
                                "12345678901234567890123456789012345678901234567890" +
                                "12345678901234567890123456789012345678901234567890" +
                                "123456789012345678901234567890123456789012345678901")

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
        XCTAssertEqual(errorResponse.error.failures?.getFailure("bio"), "is greater than maximum of 200 character(s) and is not null")
    }
}
