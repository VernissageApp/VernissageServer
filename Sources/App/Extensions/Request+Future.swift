import Vapor

extension Request {
    func fail<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }
    
    func fail<T>(_ statusCode: HTTPResponseStatus) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(Abort(statusCode))
    }

    func success() -> EventLoopFuture<Void> {
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func success<Success>(_ value: Success) -> EventLoopFuture<Success> {
        return self.eventLoop.makeSucceededFuture(value)
    }
}
