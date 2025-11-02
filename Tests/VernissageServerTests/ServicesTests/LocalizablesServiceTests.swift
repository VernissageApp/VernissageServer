//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("LocalizablesService")
struct LocalizablesServiceTests {
    
    var application: Application!
    var expectedBody = """
<html>
    <body>
        <div>Hi Jan,</div>
        <div>Your archive is ready to <a href='http://url.com/file.zip'>download</a>.</div>
    </body>
</html>
"""
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test
    func `LocalizedStringShouldBeDownloadedFromDatabase.`() async throws {
        // Act.
        let localizedEmailSubject = try await application.services.localizablesService.get(code: "email.archiveReady.subject",
                                                                                           locale: "en_US",
                                                                                           on: application.db)

        // Arrange.
        #expect(localizedEmailSubject == "Vernissage - Archive is ready", "Localized string should be downloaded.")
    }
    
    @Test
    func `LocalizedStringWithParametersShouldBeDownloadedFromDatabase.`() async throws {
        // Arrange.
        let emailVariables = [
            "name": "Jan",
            "archiveUrl": "http://url.com/file.zip"
        ]
        
        // Act.
        let localizedEmailBody = try await application.services.localizablesService.get(code: "email.archiveReady.body",
                                                                                           locale: "en_US",
                                                                                           variables: emailVariables,
                                                                                           on: application.db)

        // Arrange.
        #expect(localizedEmailBody == expectedBody, "Localized string should be downloaded.")
    }
}
