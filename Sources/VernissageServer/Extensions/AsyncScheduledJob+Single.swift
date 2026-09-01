//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Queues

public extension AsyncScheduledJob {
    func single(jobId: String, lockFor seconds: Int, on context: QueueContext) async throws -> Bool {
        // Queues and Redis are using same configuration, when Queue are not configured then Redis also is not configured.
        if context.application.queues.driver is EchoQueuesDriver {
            return true
        }

        let workerId = UUID().uuidString
        let response = try await context.application.redis.send(
            command: "SET",
            with: [
                .init(from: "scheduled-job:\(jobId)"),
                .init(from: workerId),
                .init(from: "NX"),
                .init(from: "EX"),
                .init(from: seconds)
            ]
        )

        guard response.isNull == false else {
            context.logger.info("[\(jobId)] Another instance claimed this execution.")
            return false
        }

        context.logger.info("[\(jobId)] Execution claimed by worker '\(workerId)'.")
        return true
    }
}
