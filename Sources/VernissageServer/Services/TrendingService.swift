//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import Queues

extension Application.Services {
    struct TrendingServiceKey: StorageKey {
        typealias Value = TrendingServiceType
    }

    var trendingService: TrendingServiceType {
        get {
            self.application.storage[TrendingServiceKey.self] ?? TrendingService()
        }
        nonmutating set {
            self.application.storage[TrendingServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol TrendingServiceType: Sendable {
    /// Calculates and updates trending statuses for the specified period.
    /// - Parameters:
    ///   - period: Trending period to calculate for.
    ///   - context: Queue context.
    func calculateTrendingStatuses(period: TrendingPeriod, on context: QueueContext) async

    /// Calculates and updates trending users for the specified period.
    /// - Parameters:
    ///   - period: Trending period to calculate for.
    ///   - context: Queue context.
    func calculateTrendingUsers(period: TrendingPeriod, on context: QueueContext) async

    /// Calculates and updates trending hashtags for the specified period.
    /// - Parameters:
    ///   - period: Trending period to calculate for.
    ///   - context: Queue context.
    func calculateTrendingHashtags(period: TrendingPeriod, on context: QueueContext) async

    /// Returns trending statuses for the specified period, with paging parameters.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - period: Trending period to retrieve for.
    ///   - database: Database to perform the query on.
    /// - Returns: Linkable result with trending statuses.
    /// - Throws: Database errors.
    func statuses(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<Status>

    /// Returns trending users for the specified period, with paging parameters.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - period: Trending period to retrieve for.
    ///   - database: Database to perform the query on.
    /// - Returns: Linkable result with trending users.
    /// - Throws: Database errors.
    func users(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<User>

    /// Returns trending hashtags for the specified period, with paging parameters.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - period: Trending period to retrieve for.
    ///   - database: Database to perform the query on.
    /// - Returns: Linkable result with trending hashtags.
    /// - Throws: Database errors.
    func hashtags(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<TrendingHashtag>
}

/// A service for managing the most popular entities.
final class TrendingService: TrendingServiceType {
    private struct TrendingAmount: Content {
        var id: Int64
        var amount: Int
    }

    private struct TrendingHashtagAmount: Content {
        var hashtagNormalized: String
        var hashtag: String
        var amount: Int
    }
    
    func calculateTrendingStatuses(period: TrendingPeriod, on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending statuses: \(period).")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }

            // Get old trending statuses.
            let trendingStatuses = try await self.getTrendingStatuses(period: period, on: sql)

            // Generate collection of new trending statuses.
            let newTrendingStatuses = trendingStatuses.reversed().map { amount in
                let newTrendingStatusId = context.application.services.snowflakeService.generate()
                return TrendingStatus(id: newTrendingStatusId, trendingPeriod: period, statusId: amount.id, amount: amount.amount)
            }
            
            // Modify data on database.
            try await context.application.db.transaction { database in
                // Delete old trending statuses.
                try await TrendingStatus.query(on: database)
                    .filter(\.$trendingPeriod == period)
                    .delete()
            
                // Insert new trending statuses.
                try await newTrendingStatuses.create(on: database)
            }
            
            context.logger.info("Trending statuses calculated: \(period).")
        } catch {
            await context.logger.store("Error during calculating trending statuses: \(period).", error, on: context.application)
        }
    }
    
    func calculateTrendingUsers(period: TrendingPeriod, on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending users: \(period).")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            // Get old trending users.
            let dailyTrendingAccounts = try await self.getTrendingAccounts(period: period, on: sql)
            
            // Generate collection of new trending users.
            let newTrendingAccounts = dailyTrendingAccounts.reversed().map { amount in
                let newTrendingUserId = context.application.services.snowflakeService.generate()
                return TrendingUser(id: newTrendingUserId, trendingPeriod: period, userId: amount.id, amount: amount.amount)
            }
            
            // Modify data on database.
            try await context.application.db.transaction { database in
                // Delete old trending users.
                try await TrendingUser.query(on: database)
                    .filter(\.$trendingPeriod == period)
                    .delete()
                
                // Insert new trending users.
                try await newTrendingAccounts.create(on: database)
            }
            
            context.logger.info("Trending users calculated: \(period).")
        } catch {
            await context.logger.store("Error during calculating trending accounts: \(period).", error, on: context.application)
        }
    }
    
    func calculateTrendingHashtags(period: TrendingPeriod, on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending hashtags: \(period).")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            // Get old trending hashtags.
            let dailyTrendingHashtags = try await self.getTrendingHashtags(period: period, on: sql)
            
            // Generate collection of new trending hashtags.
            let newTrendingHashtags = dailyTrendingHashtags.reversed().map { amount in
                let newTrendingHashtagId = context.application.services.snowflakeService.generate()
                return TrendingHashtag(id: newTrendingHashtagId,
                                       trendingPeriod: period,
                                       hashtag: amount.hashtag,
                                       hashtagNormalized: amount.hashtagNormalized,
                                       amount: amount.amount)
            }
            
            // Modify data on database.
            try await context.application.db.transaction { database in
                // Delete old trending hashtags.
                try await TrendingHashtag.query(on: database)
                    .filter(\.$trendingPeriod == period)
                    .delete()
                
                // Insert new trending hashtags.
                try await newTrendingHashtags.create(on: database)
            }
            
            context.logger.info("Trending hashtags calculated: \(period).")
        } catch {
            await context.logger.store("Error during calculating trending hashtags: \(period).", error, on: context.application)
        }
    }
    
    func statuses(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<Status> {

        var query = TrendingStatus.query(on: database)
            .filter(\.$trendingPeriod == period)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$user)
                .with(\.$category)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let trending = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedTrending =  trending.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedTrending.last?.stringId(),
            minId: sortedTrending.first?.stringId(),
            data: sortedTrending.map({ $0.status })
        )
    }
    
    func users(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<User> {

        var query = TrendingUser.query(on: database)
            .filter(\.$trendingPeriod == period)
            .with(\.$user) { user in
                user
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let trending = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedTrending =  trending.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedTrending.last?.stringId(),
            minId: sortedTrending.first?.stringId(),
            data: sortedTrending.map({ $0.user })
        )
    }
    
    func hashtags(linkableParams: LinkableParams, period: TrendingPeriod, on database: Database) async throws -> LinkableResult<TrendingHashtag> {

        var query = TrendingHashtag.query(on: database)
            .filter(\.$trendingPeriod == period)
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let trending = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedTrending =  trending.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedTrending.last?.stringId(),
            minId: sortedTrending.first?.stringId(),
            data: sortedTrending.map({ $0 })
        )
    }
    
    private func getTrendingStatuses(period: TrendingPeriod, on sql: SQLDatabase) async throws -> [TrendingAmount] {
        let past = period.getDate()
        
        let trendingAmounts = try await sql.raw("""
            SELECT
                \(ident: "sf").\(ident: "statusId") AS \(ident: "id"),
                COUNT(\(ident: "sf").\(ident: "statusId")) AS \(ident: "amount")
            FROM \(ident: StatusFavourite.schema) \(ident: "sf")
                INNER JOIN \(ident: Status.schema) \(ident: "s") ON \(ident: "sf").\(ident: "statusId") = \(ident: "s").\(ident: "id")
            WHERE
                \(ident: "sf").\(ident: "createdAt") > \(bind: past)
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "sf").\(ident: "statusId"), \(ident: "s").\(ident: "createdAt")
            ORDER BY COUNT(\(ident: "sf").\(ident: "statusId")), \(ident: "s").\(ident: "createdAt") DESC
            LIMIT 1000
        """).all(decoding: TrendingAmount.self)
        
        return trendingAmounts
    }
    
    private func getTrendingAccounts(period: TrendingPeriod, on sql: SQLDatabase) async throws -> [TrendingAmount] {
        let past = period.getDate()
        
        let trendingAmounts = try await sql.raw("""
            SELECT
                \(ident: "s").\(ident: "userId") AS \(ident: "id"),
                COUNT(\(ident: "s").\(ident: "userId")) AS \(ident: "amount")
            FROM \(ident: StatusFavourite.schema) \(ident: "sf")
                INNER JOIN \(ident: Status.schema) \(ident: "s") ON \(ident: "sf").\(ident: "statusId") = \(ident: "s").\(ident: "id")
            WHERE
                \(ident: "sf").\(ident: "createdAt") > \(bind: past)
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "s").\(ident: "userId")
            ORDER BY COUNT(\(ident: "s").\(ident: "userId")) DESC
            LIMIT 1000
        """).all(decoding: TrendingAmount.self)
        
        return trendingAmounts
    }
    
    private func getTrendingHashtags(period: TrendingPeriod, on sql: SQLDatabase) async throws -> [TrendingHashtagAmount] {
        let past = period.getDate()
        
        let trendingHashtag = try await sql.raw("""
            SELECT
                \(ident: "st").\(ident: "hashtagNormalized") AS \(ident: "hashtagNormalized"),
                (SELECT \(ident: "hashtag") FROM \(ident: StatusHashtag.schema) WHERE \(ident: "hashtagNormalized") = \(ident: "st").\(ident: "hashtagNormalized") LIMIT 1) AS \(ident: "hashtag"),
                COUNT(\(ident: "st").\(ident: "hashtagNormalized")) AS \(ident: "amount")
            FROM \(ident: Status.schema) \(ident: "s")
                INNER JOIN \(ident: StatusHashtag.schema) \(ident: "st") ON \(ident: "st").\(ident: "statusId") = \(ident: "s").\(ident: "id")
            WHERE
                \(ident: "s").\(ident: "createdAt") > \(bind: past)
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "st").\(ident: "hashtagNormalized")
            ORDER BY COUNT(\(ident: "st").\(ident: "hashtagNormalized")) DESC
            LIMIT 1000
        """).all(decoding: TrendingHashtagAmount.self)
        
        return trendingHashtag
    }
}
