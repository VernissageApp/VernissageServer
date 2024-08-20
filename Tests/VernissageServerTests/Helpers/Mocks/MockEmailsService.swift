//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor

final class MockEmailsService: EmailsServiceType {
    func setServerSettings(on application: Application, hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?) {
    }
    
    func dispatchForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }

    func dispatchConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
    }
}

