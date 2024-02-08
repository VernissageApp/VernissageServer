//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

class CustomTestCase : XCTestCase {
    override class func setUp() {
        // We have to be sure that application is created before any test (especially for Frostline)
        _ = try? SharedApplication.application()
    }
}
