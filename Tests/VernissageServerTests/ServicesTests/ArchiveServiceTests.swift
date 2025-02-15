//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("ArchiveService")
struct ArchiveServiceTests {

    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Archive file should be created for archive request.")
    func archiveFileShouldBeCreatedForArchiveRequest() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "robinmikox")
        let archive = try await application.createArchive(userId: user.requireID())
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "CreateArchiveJob"))
        try await application.services.archivesService.create(for: archive.requireID(), on: queueContext)
        
        // Arrange.
        let archives = try await application.getAllArchives(userId: user.requireID())
        defer {
            application.deleteFile(archives: archives)
        }
        
        #expect(archives.count == 1, "Archive should be added to the database.")
        #expect(archives.first?.status == .ready, "Archive has been created successfully.")
    }
    
    @Test("Archive file should be deleted for archive request.")
    func archiveFileShouldBeDeletedForArchiveRequest() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "annamikox")
        let archive = try await application.createArchive(userId: user.requireID())
        
        let queueContext = application.getQueueContext(queueName: QueueName(string: "CreateArchiveJob"))
        try await application.services.archivesService.create(for: archive.requireID(), on: queueContext)
        
        // Act.
        try await application.services.archivesService.delete(for: archive.requireID(), on: queueContext)
        
        // Arrange.
        let archives = try await application.getAllArchives(userId: user.requireID())
        #expect(archives.count == 1, "Archive should be added to the database.")
        #expect(archives.first?.status == .expired, "Archive has been deleted successfully.")
    }
}
