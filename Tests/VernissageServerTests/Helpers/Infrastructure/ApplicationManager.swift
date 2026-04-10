//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import VaporTesting
import Testing
import Frostflake

@MainActor
public final class ApplicationManager {
    public static let shared = ApplicationManager()
    private var application: Application?
    
    private init() {
    }

    func application() async throws -> Application {
        if let application {
            return application
        }

        let app = try await Application.make(.testing)
        app.directory = .init(workingDirectory: Self.projectRootPath())
                
        try await app.configure()

        // Services mocks.
        app.services.emailsService = MockEmailsService()
        app.services.searchService = MockSearchService()
        
        self.application = app
        return app
    }
    
    private static func projectRootPath() -> String {
        let sourceFilePath = #filePath
        guard let testsDirectoryRange = sourceFilePath.range(of: "/Tests/") else {
            return FileManager.default.currentDirectoryPath
        }
        
        return String(sourceFilePath[..<testsDirectoryRange.lowerBound])
    }
    
    func generateId() -> Int64 {
        self.application?.services.snowflakeService.generate() ?? 0
    }
}
