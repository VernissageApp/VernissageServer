//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Queues

public extension AsyncScheduledJob {
    func single(jobId: String, on context: QueueContext) async throws -> Bool {
        // Queues and Redis are using same configuration, when Queue are not configured then Redis also is not configured.
        if let _ = context.application.queues.driver as? EchoQueuesDriver {
            return true
        }
        
        // Sending token to redis memory.
        let trendingJobGuid = String.createRandomString(length: 10)
        _ = try await context.application.redis.set(key: jobId, value: trendingJobGuid)
        
        // Waiting for registering all jobs.
        sleep(5)
        
        // Checking if job can continue working.
        let value = try await context.application.redis.get(key: jobId)
        let workingJobGuid = value.string
        
        // When different token is stored in the Redis then different worker will run.
        guard workingJobGuid == trendingJobGuid else {
            context.logger.warning("Different background job instance will run job (current id: \(trendingJobGuid), working id: \(workingJobGuid ?? "").")
            return false
        }
        
        context.logger.info("Worker with id: \(trendingJobGuid) is working.")
        return true
    }
}
