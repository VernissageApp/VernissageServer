//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting

final class MockEmailsService: EmailsServiceType {
    func setServerSettings(hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?, on application: Application) {
    }
    
    func dispatchForgotPasswordEmail(user: User, redirectBaseUrl: String, on request: Request) async throws {
    }

    func dispatchConfirmAccountEmail(user: User, redirectBaseUrl: String, on request: Request) async throws {
    }
    
    func dispatchArchiveReadyEmail(archive: Archive, on context: ExecutionContext) async throws {
    }
    
    func dispatchSharedBusinessCardEmail(sharedBusinessCard: SharedBusinessCard, sharedCardUrl: String, on context: ExecutionContext) async throws {
    }
    
    func dispatchApproveAccountEmail(user: VernissageServer.User, on request: Vapor.Request) async throws {
    }
    
    func dispatchRejectAccountEmail(user: VernissageServer.User, on request: Vapor.Request) async throws {
    }
}

