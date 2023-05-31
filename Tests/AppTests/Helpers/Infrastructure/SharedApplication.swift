@testable import App
import Foundation
import XCTest
import XCTVapor

final class SharedApplication {

    private static var sharedApplication: Application? = {
        do {
            return try create()
        } catch {
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
        try app.configure()
        
        // Services mocks.
        app.services.emailsService = MockEmailsService()

        return app
    }
}
