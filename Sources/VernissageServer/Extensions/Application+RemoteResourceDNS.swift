//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import NIOPosix
import Vapor

extension Application {
    private struct RemoteResourceDNSPoolKey: StorageKey {
        typealias Value = NIOThreadPool
    }

    var remoteResourceDNSPool: NIOThreadPool? {
        self.storage[RemoteResourceDNSPoolKey.self]
    }

    func configureRemoteResourceDNS() {
        guard self.remoteResourceDNSPool == nil else {
            return
        }

        let pool = NIOThreadPool(numberOfThreads: Constants.remoteResourceDNSThreadCount)
        pool.start()
        self.storage[RemoteResourceDNSPoolKey.self] = pool
        self.lifecycle.use(RemoteResourceDNSLifecycle(pool: pool))
    }
}

private struct RemoteResourceDNSLifecycle: LifecycleHandler {
    let pool: NIOThreadPool

    func shutdown(_ application: Application) {
        do {
            try self.pool.syncShutdownGracefully()
        } catch {
            application.logger.warning("Could not shut down the remote resource DNS pool: \(error)")
        }
    }

    func shutdownAsync(_ application: Application) async {
        do {
            try await self.pool.shutdownGracefully()
        } catch {
            application.logger.warning("Could not shut down the remote resource DNS pool: \(error)")
        }
    }
}
