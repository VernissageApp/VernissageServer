//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import FluentSQLiteDriver
import QueuesRedisDriver

extension Application {

    public func registerQueues() throws {
        // In testing environment queues are disabled.
        if self.environment == .testing {
            self.logger.notice("Queues are disabled during testing (testing environment is set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            
            self.queues.use(.echo())
            return
        }
        
        guard let queueUrl = self.settings.getString(for: "vernissage.queueUrl") else {
            self.logger.notice("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }
        
        if queueUrl.isEmpty {
            self.logger.notice("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }
        
        // Activate redis (for distributed cache).
        self.redis.configuration = try RedisConfiguration(url: queueUrl,
                                                          tlsConfiguration: nil,
                                                          pool: .init(connectionRetryTimeout: .seconds(60)))

        // Activate queues.
        self.logger.info("Queues and Redis has been enabled.")
        try self.queues.use(.redis(.init(url: queueUrl, pool: .init(connectionRetryTimeout: .seconds(60)))))
        
        registerQueueJobs()
        try startQueueWorkers()
    }

    private func registerQueueJobs() {
        self.queues.add(EmailJob())
        self.queues.add(WebPushSenderJob())
        self.queues.add(UrlValidatorJob())
        self.queues.add(UserDeleterJob())
        self.queues.add(FollowingImporterJob())
        
        self.queues.add(StatusCreaterJob())
        self.queues.add(StatusUpdaterJob())
        self.queues.add(StatusDeleterJob())
        self.queues.add(StatusRebloggerJob())
        self.queues.add(StatusUnrebloggerJob())
        self.queues.add(StatusFavouriterJob())
        self.queues.add(StatusUnfavouriterJob())

        self.queues.add(ActivityPubSharedInboxJob())
        self.queues.add(ActivityPubUserInboxJob())
        self.queues.add(ActivityPubUserOutboxJob())
        self.queues.add(ActivityPubStatusJob())
        self.queues.add(FlagCreaterJob())
        
        self.queues.add(ActivityPubFollowRequesterJob())
        self.queues.add(ActivityPubFollowResponderJob())
    }

    private func startQueueWorkers() throws {
        let disableQueueJobs = self.settings.getString(for: "vernissage.disableQueueJobs")
        if disableQueueJobs == nil || disableQueueJobs == "false" {
            self.logger.notice("In process queues are enabled in the configuration.")
            
            try self.queues.startInProcessJobs(on: .default)
            
            try self.queues.startInProcessJobs(on: .emails)
            try self.queues.startInProcessJobs(on: .webPush)
            try self.queues.startInProcessJobs(on: .urlValidator)
            try self.queues.startInProcessJobs(on: .userDeleter)
            try self.queues.startInProcessJobs(on: .followingImporter)
            
            try self.queues.startInProcessJobs(on: .statusSender)
            try self.queues.startInProcessJobs(on: .statusDeleter)
            try self.queues.startInProcessJobs(on: .statusUpdater)
            try self.queues.startInProcessJobs(on: .statusReblogger)
            try self.queues.startInProcessJobs(on: .statusUnreblogger)
            try self.queues.startInProcessJobs(on: .statusFavouriter)
            try self.queues.startInProcessJobs(on: .statusUnfavouriter)
            
            try self.queues.startInProcessJobs(on: .apSharedInbox)
            try self.queues.startInProcessJobs(on: .apUserInbox)
            try self.queues.startInProcessJobs(on: .apUserOutbox)
            try self.queues.startInProcessJobs(on: .apStatus)
            try self.queues.startInProcessJobs(on: .apFlag)
            
            try self.queues.startInProcessJobs(on: .apFollowRequester)
            try self.queues.startInProcessJobs(on: .apFollowResponder)
        } else {
            self.logger.notice("All in process queues are disabled in the configuration.")
        }
    }
}
