@testable import App
import XCTest
import XCTVapor


final class EmailActionTests: XCTestCase {

    func testEmailValidationShouldReturnTrueIfEmailExists() throws {

        // Arrange.
        _ = try User.create(userName: "tomsmith")

        // Act.
        let booleanResponseDto = try SharedApplication.application()
            .getResponse(to: "/register/email/tomsmith@testemail.com", decodeTo: BooleanResponseDto.self)

        // Assert.
        XCTAssert(booleanResponseDto.result, "Server should return true for email: tomsmith@testemail.com.")
    }

    func testEmailValidationShouldReturnFalseIfEmailNotExists() throws {

        // Arrange.
        let url = "/register/email/notexists@testemail.com"

        // Act.
        let booleanResponseDto = try SharedApplication.application()
            .getResponse(to: url, decodeTo: BooleanResponseDto.self)

        // Assert.
        XCTAssert(booleanResponseDto.result == false, "Server should return false for email: notexists@testemail.com.")
    }
}
