//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor

final class MockEmailsService: EmailsServiceType {
    func sendForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }

    func sendConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }
}

