//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues

protocol RetryableAsyncJob: AsyncJob { }

extension RetryableAsyncJob {
    func nextRetryIn(attempt: Int) -> Int {
        switch attempt {
        case 1:
            return 1 * 60
        case 2:
            return 5 * 60
        case 3:
            return 15 * 60
        default:
            return 0
        }
    }
}
