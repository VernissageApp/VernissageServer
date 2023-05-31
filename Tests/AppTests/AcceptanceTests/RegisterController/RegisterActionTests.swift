@testable import App
import XCTest
import XCTVapor
import Fluent

final class RegisterActionTests: XCTestCase {

    func testUserAccountShouldBeCreatedForValidUserData() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "annasmith",
                                              email: "annasmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Anna Smith",
                                              securityToken: "123")

        // Act.
        let createdUserDto = try SharedApplication.application()
            .getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssert(createdUserDto.id != nil, "User wasn't created.")
    }

    func testCreatedStatusCodeShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "martinsmith",
                                              email: "martinsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Martin Smith",
                                              securityToken: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register", method: .POST, body: registerUserDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
    }

    func testHeaderLocationShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "victoriasmith",
                                              email: "victoriasmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Victoria Smith",
                                              securityToken: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register", method: .POST, body: registerUserDto)

        // Assert.
        let location = response.headers.first(name: .location)
        let user = try response.content.decode(UserDto.self)
        XCTAssertEqual(location, "/users/@\(user.userName)", "Location header should contains created username.")
    }

    func testCorrectUserDataShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "dansmith",
                                              email: "dansmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Dan Smith",
                                              bio: "User biography",
                                              location: "London",
                                              website: "http://dansmith.com/",
                                              birthDate: Date(),
                                              securityToken: "123")

        // Act.
        let createdUserDto = try SharedApplication.application().getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssertEqual(createdUserDto.userName, "dansmith", "User name is not correcrt.")
        XCTAssertEqual(createdUserDto.email, "dansmith@testemail.com", "Email is not correct.")
        XCTAssertEqual(createdUserDto.name, "Dan Smith", "Name is not correct.")
        XCTAssertEqual(createdUserDto.bio, "User biography", "User biography is not correct")
        XCTAssertEqual(createdUserDto.location, "London", "Location is not correct")
        XCTAssertEqual(createdUserDto.website, "http://dansmith.com/", "Website is not correct")
        XCTAssertEqual(createdUserDto.birthDate?.description, registerUserDto.birthDate?.description, "Birth date is not correct")
        XCTAssertEqual(createdUserDto.gravatarHash, "5a00c583025fbdb133a446223f627a12", "Gravatar is not correct")
    }

    func testNewUserShouldBeAssignedToDefaultRoles() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "briansmith",
                                              email: "briansmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Brian Smith",
                                              securityToken: "123")

        // Act.
        _ = try SharedApplication.application().getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        let user = try User.get(userName: "briansmith")
        XCTAssertEqual(user.roles[0].code, "member", "Default user roles should be added to user")
    }

    func testUserShouldNotBeCreatedIfUserWithTheSameEmailExists() throws {

        // Arrange.
        _ = try User.create(userName: "jurgensmith",
                            email: "jurgensmith@testemail.com",
                            name: "Jurgen Smith")

        let registerUserDto = RegisterUserDto(userName: "notexists",
                                              email: "jurgensmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Jurgen Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "emailIsAlreadyConnected", "Error code should be equal 'emailIsAlreadyConnected'.")
    }

    func testUserShouldNotBeCreatedIfUserWithTheSameUserNameExists() throws {

        // Arrange.
        _ = try User.create(userName: "teddysmith")
        let registerUserDto = RegisterUserDto(userName: "teddysmith",
                                              email: "teddysmith-notexists@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Samantha Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userNameIsAlreadyTaken", "Error code should be equal 'userNameIsAlreadyTaken'.")
    }

    func testUserShouldNotBeCreatedIfUserNameWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userName"), "is less than minimum of 1 character(s)")
    }

    func testUserShouldNotBeCreatedIfUserNameWasTooLong() throws {
    
        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "123456789012345678901234567890123456789012345678901",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userName"), "is greater than maximum of 50 character(s)")
    }

    func testUserShouldNotBeCreatedIfEmailWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("email"), "is not a valid email address")
    }

    func testUserShouldNotBeCreatedIfEmailHasWrongFormat() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmithtestemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("email"), "is not a valid email address")
    }

    func testUserShouldNotBeCreatedIfPasswordWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfPasswordIsTooShort() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "1234567",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfPasswordIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "123456789012345678901234567890123",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is greater than maximum of 32 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfNameIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("name"), "is not null and is greater than maximum of 50 character(s)")
    }

    func testUserShouldNotBeCreatedIfLocationIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              location: "123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("location"), "is not null and is greater than maximum of 50 character(s)")
    }

    func testUserShouldNotBeCreatedIfWebsiteIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              website: "123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("website"), "is not null and is greater than maximum of 50 character(s)")
    }

    func testUserShouldNotBeCreatedIfBioIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              bio: "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("bio"), "is not null and is greater than maximum of 200 character(s)")
    }

    func testUserShouldNotBeCreatedIfSecurityTokenWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              name: "Greg Smith",
                                              securityToken: nil)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("securityToken"), "is required")
    }
}
