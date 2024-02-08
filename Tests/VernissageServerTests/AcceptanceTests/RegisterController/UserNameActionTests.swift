//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class UserNameActionTests: CustomTestCase {

    func testUserNameValidationShouldReturnTrueIfUserNameExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "johndoe")

        // Act.
        let booleanResponseDto = try SharedApplication.application()
            .getResponse(to: "/register/username/johndoe", decodeTo: BooleanResponseDto.self)

        // Assert.
        XCTAssert(booleanResponseDto.result, "Server should return true for username: johndoe.")
    }

    func testUserNameValidationShouldReturnFalseIfUserNameNotExists() throws {

        // Arrange.
        let url = "/register/username/notexists"

        // Act.
        let booleanResponseDto = try SharedApplication.application()
            .getResponse(to: url, decodeTo: BooleanResponseDto.self)

        // Assert.
        XCTAssert(booleanResponseDto.result == false, "Server should return false for username: notexists.")
    }
}
