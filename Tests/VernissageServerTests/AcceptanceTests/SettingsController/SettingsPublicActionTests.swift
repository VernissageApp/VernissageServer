//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

@Suite("GET /public", .serialized, .tags(.settings))
struct SettingsPublicActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("List of public settings should be returned for not authorized")
    func listOfPublicSettingsShouldBeReturnedForNotAuthorized() async throws {

        // Act.
        let settings = try application.getResponse(
            to: "/settings/public",
            method: .GET,
            decodeTo: PublicSettingsDto.self
        )

        // Assert.
        #expect(settings != nil, "Public settings should be returned.")
    }
}
