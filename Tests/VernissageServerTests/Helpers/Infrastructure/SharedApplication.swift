//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import XCTest
import XCTVapor

final class SharedApplication {

    private static var sharedApplication: Application? = {
        do {
            return try create()
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }()

    private init() {
    }

    class func application() throws -> Application {
        if let application = sharedApplication {
            return application
        } else {
            throw SharedApplicationError.unknown
        }
    }
    
    public static func testable() throws -> XCTApplicationTester {
        return try application().testable()
    }

    private static func create() throws -> Application {
        let app = Application(.testing)
        
        wait {
            try await app.configure()
        }
        
        // Services mocks.
        app.services.emailsService = MockEmailsService()

        return app
    }
    
    private static func wait(asyncBlock: @escaping (() async throws -> Void)) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await asyncBlock()
                semaphore.signal()
            } catch {
                print(error)
                semaphore.signal()
            }
        }
        semaphore.wait()
    }
}
