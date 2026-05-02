//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Application {

    func registerSchedulers() throws {
        // During testing we shouldn't run any background jobs.
        if self.environment == .testing {
            return
        }

        registerDayJobs()
        registerNightJobs()
        try startSchedulers()
    }

    private func registerDayJobs() {
        self.queues.schedule(ClearAttachmentsJob()).hourly().at(15)
        self.queues.schedule(ShortPeriodTrendingJob()).hourly().at(30)
        self.queues.schedule(ClearQuickCaptchasJob()).hourly().at(52)

        // Purge statuses three times per hour.
        self.queues.schedule(PurgeStatusesJob()).hourly().at(05)
        self.queues.schedule(PurgeStatusesJob()).hourly().at(20)
        self.queues.schedule(PurgeStatusesJob()).hourly().at(35)
        self.queues.schedule(PurgeStatusesJob()).hourly().at(50)
        
        self.queues.schedule(RescheduleActivityPubJob()).hourly().at(15)
        self.queues.schedule(RescheduleActivityPubJob()).hourly().at(45)
    }

    private func registerNightJobs() {
        self.queues.schedule(CreateArchiveJob()).daily().at(1, 10)
        self.queues.schedule(DeleteArchiveJob()).daily().at(2, 15)
        self.queues.schedule(LongPeriodTrendingJob()).daily().at(3, 15)
        self.queues.schedule(ClearDeletedUsersJob()).daily().at(3, 45)
        self.queues.schedule(LocationsJob()).daily().at(4, 15)
        self.queues.schedule(ClearErrorItemsJob()).daily().at(5, 15)
        self.queues.schedule(ClearFailedLoginsJob()).daily().at(5, 30)
    }

    private func startSchedulers() throws {
        let disableScheduledJobs = self.settings.getString(for: "vernissage.disableScheduledJobs")
        if disableScheduledJobs == nil || disableScheduledJobs == "false" {
            self.logger.notice("In process schedulers are enabled in the configuration.")
            try self.queues.startScheduledJobs()
        } else {
            self.logger.notice("All in process schedulers are disabled in the configuration.")
        }
    }
}
