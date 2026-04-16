//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("SuspendedServersService", .serialized)
struct SuspendedServersServiceTests {

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Connection error should create suspended server entry.`() async throws {
        // Arrange.
        try await application.clearSuspendedServers()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let suspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)

        // Act.
        try await suspendedServersService.registerConnectionError(for: "MiXeD.Example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)

        // Assert.
        let suspendedServer = try await application.getSuspendedServer(hostNormalized: "MIXED.EXAMPLE.COM")
        #expect(suspendedServer != nil, "Suspended server entry should be created.")
        #expect(suspendedServer?.numberOfErrors == 1, "First connection error should set error counter to 1.")
        #expect(suspendedServer?.hostNormalized == "MIXED.EXAMPLE.COM", "Host should be normalized to uppercase.")
    }

    @Test
    func `Host should be suspended after reaching errors limit.`() async throws {
        // Arrange.
        try await application.clearSuspendedServers()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let suspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)

        // Act.
        try await suspendedServersService.registerConnectionError(for: "down.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)
        try await suspendedServersService.registerConnectionError(for: "down.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)
        try await suspendedServersService.registerConnectionError(for: "down.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)
        let suspendedServers = await suspendedServersService.getSnapshot(on: queueContext.executionContext)

        // Assert.
        let shouldSend = await suspendedServersService.shouldSend(to: "down.example.com", basedOn: suspendedServers)
        #expect(shouldSend == false, "Host should be suspended after reaching error limit.")
    }

    @Test
    func `After suspension period one failed retry should suspend host again.`() async throws {
        // Arrange.
        try await application.clearSuspendedServers()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let suspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)

        try await suspendedServersService.registerConnectionError(for: "retry.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)
        try await suspendedServersService.registerConnectionError(for: "retry.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)
        try await suspendedServersService.registerConnectionError(for: "retry.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)

        let suspendedServer = try #require(await application.getSuspendedServer(hostNormalized: "RETRY.EXAMPLE.COM"))
        suspendedServer.lastErrorDate = Date().addingTimeInterval(-(24 * 60 * 60 + 60))
        try await suspendedServer.save(on: application.db)

        // Create new service instance to load fresh state from database.
        let reloadedSuspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)
        let reloadedSuspendedServers = await reloadedSuspendedServersService.getSnapshot(on: queueContext.executionContext)

        // Act.
        let shouldSendAfter24Hours = await reloadedSuspendedServersService.shouldSend(to: "retry.example.com",
                                                                                      basedOn: reloadedSuspendedServers)
        try await reloadedSuspendedServersService.registerConnectionError(for: "retry.example.com",
                                                                          error: URLError(.cannotConnectToHost),
                                                                          on: queueContext.executionContext)
        let updatedSnapshot = await reloadedSuspendedServersService.getSnapshot(on: queueContext.executionContext)
        let shouldSendAfterNextError = await reloadedSuspendedServersService.shouldSend(to: "retry.example.com",
                                                                                        basedOn: updatedSnapshot)

        // Assert.
        #expect(shouldSendAfter24Hours == true, "Host should be retried after suspension window.")
        #expect(shouldSendAfterNextError == false, "One failed retry should suspend host again.")
    }

    @Test
    func `Successful request should remove host from suspended list.`() async throws {
        // Arrange.
        try await application.clearSuspendedServers()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let suspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)

        try await suspendedServersService.registerConnectionError(for: "recovered.example.com",
                                                                  error: URLError(.cannotConnectToHost),
                                                                  on: queueContext.executionContext)

        // Act.
        try await suspendedServersService.registerSuccess(for: "recovered.example.com", on: queueContext.executionContext)

        // Assert.
        let suspendedServer = try await application.getSuspendedServer(hostNormalized: "RECOVERED.EXAMPLE.COM")
        #expect(suspendedServer == nil, "Suspended server should be removed after successful request.")
    }

    @Test
    func `Non connection error should not create suspended server entry.`() async throws {
        // Arrange.
        try await application.clearSuspendedServers()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let suspendedServersService = SuspendedServersService(maxNumberOfErrors: 3)

        // Act.
        try await suspendedServersService.registerConnectionError(for: "http-error.example.com",
                                                                  error: Abort(.badRequest),
                                                                  on: queueContext.executionContext)

        // Assert.
        let suspendedServer = try await application.getSuspendedServer(hostNormalized: "HTTP-ERROR.EXAMPLE.COM")
        #expect(suspendedServer == nil, "Only connection errors should be tracked as suspended server errors.")
    }
}
