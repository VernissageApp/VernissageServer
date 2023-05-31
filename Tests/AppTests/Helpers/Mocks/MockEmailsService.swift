@testable import App
import XCTVapor

final class MockEmailsService: EmailsServiceType {
    func sendForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }

    func sendConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }
}

