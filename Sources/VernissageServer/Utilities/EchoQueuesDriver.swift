import Vapor
import Queues
import NIOCore

extension Application.Queues.Provider {
    /// Driver used only for development purposes. Driver only displays information that Jobs will be not executed.
    public static func echo() -> Self {
        .init {
            $0.queues.use(custom: EchoQueuesDriver(on: $0.eventLoopGroup))
        }
    }
}

/// A queue driver that does nothing.
struct EchoQueuesDriver {
    public init(on eventLoopGroup: EventLoopGroup) {
    }
}

extension EchoQueuesDriver: QueuesDriver {
    public func makeQueue(with context: QueueContext) -> Queue {
        EchoQueue(context: context)
    }
    
    public func shutdown() {
    }
}

/// A queue that does nothing.
struct EchoQueue: Queue {
    var context: Queues.QueueContext
    
    func get(_ id: Queues.JobIdentifier) -> EventLoopFuture<Queues.JobData> {
        return context.eventLoop.future(JobData(payload: [], maxRetryCount: 0, jobName: "", delayUntil: Date(), queuedAt: Date()))
    }
    
    func set(_ id: Queues.JobIdentifier, to data: Queues.JobData) -> EventLoopFuture<Void> {
        return context.eventLoop.future()
    }
    
    func clear(_ id: Queues.JobIdentifier) -> EventLoopFuture<Void> {
        return context.eventLoop.future()
    }
    
    func pop() -> EventLoopFuture<Queues.JobIdentifier?> {
        return context.eventLoop.future(JobIdentifier(string: UUID().uuidString))
    }
    
    func push(_ id: Queues.JobIdentifier) -> EventLoopFuture<Void> {
        self.logger.warning("Echo driver used as a queue driver. Jobs are not working!")
        return context.eventLoop.future()
    }
}
