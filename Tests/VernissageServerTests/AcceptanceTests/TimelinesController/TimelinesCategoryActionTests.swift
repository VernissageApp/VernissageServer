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

extension TimelinesControllerTests {
    
    @Suite("GET /category/:category", .serialized, .tags(.timelines))
    struct TimelinesCategoryActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Statuses should be returned for unauthorized without params when public access is enabled")
        func statusesShouldBeReturnedForUnauthorizedWithoutParamsWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "timfucher")
            let category1 = try await application.getCategory(name: "Abstract")!
            let category2 = try await application.getCategory(name: "Nature")!
            let (_, attachments1) = try await application.createStatuses(user: user,
                                                                         notePrefix: "Category abstract note",
                                                                         categoryId: category1.stringId()!,
                                                                         amount: 4)
            
            let (_, attachments2) = try await application.createStatuses(user: user,
                                                                         notePrefix: "Category nature note",
                                                                         categoryId: category2.stringId()!,
                                                                         amount: 4)
            
            defer {
                application.clearFiles(attachments: attachments1)
                application.clearFiles(attachments: attachments2)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                to: "/timelines/category/\(category1.name.lowercased())?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Category abstract note 4", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Category abstract note 3", "Second status is not visible.")
        }
        
        @Test("Statuses should be returned for unauthorized with minId when public access is enabled")
        func statusesShouldBeReturnedForUnauthorizedWithMinIdWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "tomfucher")
            let category = try await application.getCategory(name: "Still Life")!
            let (statuses, attachments) = try await application.createStatuses(user: user,
                                                                               notePrefix: "Category note",
                                                                               categoryId: category.stringId()!,
                                                                               amount: 10)
            
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                to: "/timelines/category/still%20life?limit=2&minId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Category note 8", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Category note 7", "Second status is not visible.")
        }
        
        @Test("Statuses should be returned for unauthorized with maxId when public access is eisabled")
        func statusesShouldBeReturnedForUnauthorizedWithMaxIdWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "ronfucher")
            let category = try await application.getCategory(name: "Abstract")!
            let (statuses, attachments) = try await application.createStatuses(user: user,
                                                                               notePrefix: "Category note",
                                                                               categoryId: category.stringId()!,
                                                                               amount: 10)
            
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                to: "/timelines/category/\(category.name.lowercased())?limit=2&maxId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Category note 5", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Category note 4", "Second status is not visible.")
        }
        
        @Test("Statuses should be returned for unauthorized with sinceId")
        func statusesShouldBeReturnedForUnauthorizedWithSinceId() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "gregfucher")
            let category = try await application.getCategory(name: "Abstract")!
            let (statuses, attachments) = try await application.createStatuses(user: user,
                                                                               notePrefix: "Category note",
                                                                               categoryId: category.stringId()!,
                                                                               amount: 10)
            
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                to: "/timelines/category/\(category.name.lowercased())?limit=20&sinceId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Category note 10", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Category note 9", "Second status is not visible.")
            #expect(statusesFromApi.data[2].note == "Category note 8", "Third status is not visible.")
            #expect(statusesFromApi.data[3].note == "Category note 7", "Fourth status is not visible.")
        }
        
        @Test("Statuses should not be returned for unauthorized when public access is disabled")
        func statusesShouldNotBeReturnedForUnauthorizedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(
                to: "/timelines/category/street",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
