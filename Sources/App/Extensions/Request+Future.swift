//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

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
