//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentKit
import Queues

/// Shared context for `Request` and `QueueContext`.
/// Allows using the same services regardless of whether
/// the code is executed by an HTTP controller or a background job.
public final class ExecutionContext: Sendable {
    public let request: Request?
    public let context: QueueContext?
    private let transaction: Database?

    public init(request: Request) {
        self.request = request
        self.context = nil
        self.transaction = nil
    }

    public init(context: QueueContext) {
        self.request = nil
        self.context = context
        self.transaction = nil
    }

    private init(request: Request?, context: QueueContext?, transaction: Database) {
        self.request = request
        self.context = context
        self.transaction = transaction
    }

    var application: Application {
        request?.application ?? context!.application
    }

    var logger: Logger {
        request?.logger
            ?? context?.logger
            ?? application.logger
    }

    var cache: Cache {
        request?.cache ?? application.cache
    }

    var services: Application.Services {
        application.services
    }

    var settings: Application.Settings {
        application.settings
    }

    var db: Database {
        transaction
            ?? request?.db
            ?? context?.application.db
            ?? application.db
    }

    var userId: Int64? {
        request?.userId
    }

    var fileio: FileIO? {
        request?.fileio
    }

    var client: Client {
        request?.client
            ?? context?.application.client
            ?? application.client
    }

    var eventLoop: EventLoop {
        request?.eventLoop
            ?? context?.eventLoop
            ?? application.eventLoopGroup.next()
    }

    public func queues(_ queue: QueueName, logger: Logger? = nil) -> any Queue {
        request?.queues(queue, logger: logger)
            ?? context?.queues(queue)
            ?? application.queues.queue(queue, logger: logger)
    }

    /// Creates a context that uses the database handle associated with an already opened transaction.
    func with(transaction: Database) -> ExecutionContext {
        ExecutionContext(request: request, context: context, transaction: transaction)
    }
}

extension Request {
    var executionContext: ExecutionContext {
        ExecutionContext(request: self)
    }
}

extension QueueContext {
    var executionContext: ExecutionContext {
        ExecutionContext(context: self)
    }
}
