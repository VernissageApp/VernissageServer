//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
protocol TrendingServiceType {
    func calculateTrendingStatuses(on context: QueueContext) async
    func calculateTrendingUsers(on context: QueueContext) async
    func calculateTrendingHashtags(on context: QueueContext) async
    func statuses(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<Status>
    func users(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<User>
    func hashtags(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<TrendingHashtag>
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
    
    func calculateTrendingStatuses(on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending statuses.")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            let dailyTrendingStatuses = try await self.getTrendingStatuses(period: .daily, on: sql)
            let montlyTrendingStatuses = try await self.getTrendingStatuses(period: .monthly, on: sql)
            let yearlyTrendingStatuses = try await self.getTrendingStatuses(period: .yearly, on: sql)

            try await context.application.db.transaction { database in
                try await TrendingStatus.query(on: database)
                    .delete()
                
                try await dailyTrendingStatuses.reversed().asyncForEach { amount in
                    let item = TrendingStatus(trendingPeriod: .daily, statusId: amount.id)
                    try await item.create(on: database)
                }
                
                try await montlyTrendingStatuses.reversed().asyncForEach { amount in
                    let item = TrendingStatus(trendingPeriod: .monthly, statusId: amount.id)
                    try await item.create(on: database)
                }
                
                try await yearlyTrendingStatuses.reversed().asyncForEach { amount in
                    let item = TrendingStatus(trendingPeriod: .yearly, statusId: amount.id)
                    try await item.create(on: database)
                }
            }
            
            context.logger.info("Trending statuses calculated.")
        } catch {
            context.logger.error("Error during calculating trending statuses: \(error).")
        }
    }
    
    func calculateTrendingUsers(on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending users.")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            let dailyTrendingAccounts = try await self.getTrendingAccounts(period: .daily, on: sql)
            let montlyTrendingAccounts = try await self.getTrendingAccounts(period: .monthly, on: sql)
            let yearlyTrendingAccounts = try await self.getTrendingAccounts(period: .yearly, on: sql)
            
            try await context.application.db.transaction { database in
                try await TrendingUser.query(on: database)
                    .delete()
                
                try await dailyTrendingAccounts.reversed().asyncForEach { amount in
                    let item = TrendingUser(trendingPeriod: .daily, userId: amount.id)
                    try await item.create(on: database)
                }
                
                try await montlyTrendingAccounts.reversed().asyncForEach { amount in
                    let item = TrendingUser(trendingPeriod: .monthly, userId: amount.id)
                    try await item.create(on: database)
                }
                
                try await yearlyTrendingAccounts.reversed().asyncForEach { amount in
                    let item = TrendingUser(trendingPeriod: .yearly, userId: amount.id)
                    try await item.create(on: database)
                }
            }
            
            context.logger.info("Trending users calculated.")
        } catch {
            context.logger.error("Error during calculating trending accounts: \(error).")
        }
    }
    
    func calculateTrendingHashtags(on context: QueueContext) async {
        do {
            context.logger.info("Starting calculating trending hashtags.")
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            let dailyTrendingHashtags = try await self.getTrendingHashtags(period: .daily, on: sql)
            let montlyTrendingHashtags = try await self.getTrendingHashtags(period: .monthly, on: sql)
            let yearlyTrendingHashtags = try await self.getTrendingHashtags(period: .yearly, on: sql)
            
            try await context.application.db.transaction { database in
                try await TrendingHashtag.query(on: database)
                    .delete()
                
                try await dailyTrendingHashtags.reversed().asyncForEach { amount in
                    let item = TrendingHashtag(trendingPeriod: .daily, hashtag: amount.hashtag, hashtagNormalized: amount.hashtagNormalized)
                    try await item.create(on: database)
                }
                
                try await montlyTrendingHashtags.reversed().asyncForEach { amount in
                    let item = TrendingHashtag(trendingPeriod: .monthly, hashtag: amount.hashtag, hashtagNormalized: amount.hashtagNormalized)
                    try await item.create(on: database)
                }
                
                try await yearlyTrendingHashtags.reversed().asyncForEach { amount in
                    let item = TrendingHashtag(trendingPeriod: .yearly, hashtag: amount.hashtag, hashtagNormalized: amount.hashtagNormalized)
                    try await item.create(on: database)
                }
            }
            
            context.logger.info("Trending hashtags calculated.")
        } catch {
            context.logger.error("Error during calculating trending hashtags: \(error).")
        }
    }
    
    func statuses(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<Status> {

        var query = TrendingStatus.query(on: database)
            .filter(\.$trendingPeriod == period)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
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
    
    func users(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<User> {

        var query = TrendingUser.query(on: database)
            .filter(\.$trendingPeriod == period)
            .with(\.$user) { user in
                user.with(\.$flexiFields)
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
    
    func hashtags(on database: Database, linkableParams: LinkableParams, period: TrendingPeriod) async throws -> LinkableResult<TrendingHashtag> {

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
            ORDER BY COUNT(\(ident: "s").\(ident: "userId"))
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
            FROM \(ident: StatusFavourite.schema) \(ident: "sf")
                INNER JOIN \(ident: Status.schema) \(ident: "s") ON \(ident: "sf").\(ident: "statusId") = \(ident: "s").\(ident: "id")
                INNER JOIN \(ident: StatusHashtag.schema) \(ident: "st") ON \(ident: "st").\(ident: "statusId") = \(ident: "s").\(ident: "id")
            WHERE
                \(ident: "sf").\(ident: "createdAt") > \(bind: past)
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "st").\(ident: "hashtagNormalized")
            ORDER BY COUNT(\(ident: "st").\(ident: "hashtagNormalized"))
            LIMIT 1000
        """).all(decoding: TrendingHashtagAmount.self)
        
        return trendingHashtag
    }
}
