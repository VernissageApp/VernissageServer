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

protocol TrendingServiceType {
    func calculateTrendingStatuses(on context: QueueContext) async
    func statuses(on database: Database, linkableParams: LinkableParams, period: TrendingStatusPeriod) async throws -> LinkableResult<Status>
}

final class TrendingService: TrendingServiceType {
    private struct StatusAmount: Content {
        var statusId: Int64
        var amount: Int
    }
    
    func calculateTrendingStatuses(on context: QueueContext) async {
        do {
            guard let sql = context.application.db as? SQLDatabase else {
                return
            }
            
            let dailyTrendingStatuses = try await self.getTrendingStatuses(period: .daily, on: sql)
            let montlyTrendingStatuses = try await self.getTrendingStatuses(period: .monthly, on: sql)
            let yearlyTrendingStatuses = try await self.getTrendingStatuses(period: .yearly, on: sql)

            try await context.application.db.transaction { database in
                try await TrendingStatus.query(on: database)
                    .delete()
                
                try await dailyTrendingStatuses.reversed().asyncForEach { statusAmount in
                    let item = TrendingStatus(trendingStatusPeriod: .daily, statusId: statusAmount.statusId)
                    try await item.create(on: database)
                }
                
                try await montlyTrendingStatuses.reversed().asyncForEach { statusAmount in
                    let item = TrendingStatus(trendingStatusPeriod: .monthly, statusId: statusAmount.statusId)
                    try await item.create(on: database)
                }
                
                try await yearlyTrendingStatuses.reversed().asyncForEach { statusAmount in
                    let item = TrendingStatus(trendingStatusPeriod: .yearly, statusId: statusAmount.statusId)
                    try await item.create(on: database)
                }
            }
        } catch {
            context.logger.error("Error during calculating monthly trending statuses: \(error).")
        }
    }
    
    func statuses(on database: Database, linkableParams: LinkableParams, period: TrendingStatusPeriod) async throws -> LinkableResult<Status> {

        var query = TrendingStatus.query(on: database)
            .filter(\.$trendingStatusPeriod == period)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
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
    
    private func getTrendingStatuses(period: TrendingStatusPeriod, on sql: SQLDatabase) async throws -> [StatusAmount] {
        let monthAgo = period.getDate()
        
        let statusAmounts = try await sql.raw("""
            SELECT
                \(ident: "sf").\(ident: "statusId") AS \(ident: "statusId"),
                COUNT(\(ident: "sf").\(ident: "statusId")) AS \(ident: "amount")
            FROM \(ident: StatusFavourite.schema) \(ident: "sf")
                INNER JOIN \(ident: Status.schema) \(ident: "s") ON \(ident: "sf").\(ident: "statusId") = \(ident: "s").\(ident: "id")
            WHERE
                \(ident: "sf").\(ident: "createdAt") > \(bind: monthAgo)
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "sf").\(ident: "statusId")
            ORDER BY COUNT(\(ident: "sf").\(ident: "statusId"))
            LIMIT 1000
        """).all(decoding: StatusAmount.self)
        
        return statusAmounts
    }
    
}
