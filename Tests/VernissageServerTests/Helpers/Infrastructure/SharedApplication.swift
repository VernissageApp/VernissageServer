//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import XCTest
import XCTVapor

@MainActor
public final class ApplicationManager {
    public static let shared = ApplicationManager()
    var application: Application?
    
    private init() {
    }

    func initApplication() async throws  {
        if application != nil {
            return
        }

        let app = try await Application.make(.testing)
                
        try await app.configure()

        // Services mocks.
        app.services.emailsService = MockEmailsService()
        app.services.searchService = MockSearchService()
        
        self.application = app
    }
}
