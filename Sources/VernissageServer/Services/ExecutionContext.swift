//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentKit
import Queues

/// This is a class which wrpas Vapr request or context.
/// Thannks to that class we don't have to duplicate functions.
public final class ExecutionContext: Sendable {
    public let request: Request?
    public let context: QueueContext?
    
    public init(request: Request) {
        self.request = request
        self.context = nil
    }
    
    public init(context: QueueContext) {
        self.request = nil
        self.context = context
    }
    
    var application: Application {
        request?.application ?? context!.application
    }
    
    var logger: Logger {
        request?.logger
            ?? context?.logger
            ?? application.logger
    }
    
    var services: Application.Services {
        application.services
    }
    
    var settings: Application.Settings {
        application.settings
    }
    
    var db: Database {
        request?.db
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
