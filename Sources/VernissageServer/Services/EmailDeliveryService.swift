//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Foundation
import Queues
import Vapor

extension Application.Services {
    struct EmailDeliveryServiceKey: StorageKey {
        typealias Value = EmailDeliveryServiceType
    }

    var emailDeliveryService: EmailDeliveryServiceType {
        get {
            self.application.storage[EmailDeliveryServiceKey.self] ?? EmailDeliveryService()
        }
        nonmutating set {
            self.application.storage[EmailDeliveryServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol EmailDeliveryServiceType: Sendable {
    /// Persists an email delivery in the waiting state.
    ///
    /// - Parameters:
    ///   - email: The complete email payload to persist for later delivery.
    ///   - context: The execution context providing access to the database and application settings.
    /// - Returns: The identifier of the persisted email delivery.
    /// - Throws: An error if the delivery cannot be persisted or its identifier cannot be read.
    func create(_ email: EmailDto, on context: ExecutionContext) async throws -> Int64

    /// Persists an email delivery and immediately attempts to enqueue it for background processing.
    ///
    /// Queue dispatch errors are logged and leave the persisted delivery available to the scheduler.
    ///
    /// - Parameters:
    ///   - email: The complete email payload to persist and enqueue.
    ///   - context: The execution context providing access to the database and job queues.
    /// - Throws: An error if the delivery cannot be persisted.
    func createAndDispatch(_ email: EmailDto, on context: ExecutionContext) async throws

    /// Attempts to enqueue a persisted email delivery for background processing.
    ///
    /// Dispatch errors are logged without changing the persisted delivery state.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the email delivery to enqueue.
    ///   - context: The execution context providing access to the email job queue.
    func dispatch(emailDeliveryId: Int64, on context: ExecutionContext) async

    /// Finds email deliveries eligible for processing and attempts to enqueue each of them.
    ///
    /// - Parameter context: The execution context providing access to the database and job queues.
    /// - Throws: An error if eligible delivery identifiers cannot be read from the database.
    func dispatchPending(on context: ExecutionContext) async throws

    /// Returns identifiers of email deliveries eligible for processing or retry.
    ///
    /// This includes waiting deliveries, retries whose delay has elapsed, and deliveries whose processing lease expired.
    ///
    /// - Parameter context: The execution context providing access to the database.
    /// - Returns: A batch of eligible delivery identifiers ordered by creation date.
    /// - Throws: An error if the eligible deliveries cannot be read from the database.
    func pendingDeliveryIds(on context: ExecutionContext) async throws -> [Int64]

    /// Atomically claims an eligible email delivery and reconstructs its email job payload.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the delivery to claim.
    ///   - context: The execution context providing access to the database.
    /// - Returns: The email job payload, or `nil` when the delivery is missing or no longer eligible.
    /// - Throws: An error if the delivery cannot be claimed or read from the database.
    func prepareForSending(emailDeliveryId: Int64, on context: ExecutionContext) async throws -> EmailJobDto?

    /// Starts an SMTP attempt for a claimed delivery and increments its attempt counter.
    ///
    /// The processing token is rotated so stale or duplicate jobs cannot complete the attempt.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the claimed email delivery.
    ///   - processingToken: The token proving ownership of the current processing lease.
    ///   - context: The execution context providing access to the database.
    /// - Returns: The started attempt, or `nil` when the delivery is no longer owned by the caller.
    /// - Throws: An error if the attempt cannot be started or persisted.
    func beginAttempt(emailDeliveryId: Int64,
                      processingToken: String,
                      on context: ExecutionContext) async throws -> EmailDeliveryAttempt?

    /// Marks an owned email delivery as successfully delivered.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the email delivery to complete.
    ///   - processingToken: The token proving ownership of the active SMTP attempt.
    ///   - context: The execution context providing access to the database.
    /// - Throws: An error if the successful state cannot be persisted.
    func markSucceeded(emailDeliveryId: Int64,
                       processingToken: String,
                       on context: ExecutionContext) async throws

    /// Records a failed SMTP attempt and schedules a retry or marks the delivery as permanently failed.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the email delivery whose attempt failed.
    ///   - processingToken: The token proving ownership of the active SMTP attempt.
    ///   - error: The delivery error to persist for diagnostics.
    ///   - context: The execution context providing access to the database.
    /// - Throws: An error if the failed state cannot be persisted.
    func markFailed(emailDeliveryId: Int64,
                    processingToken: String,
                    error: Error,
                    on context: ExecutionContext) async throws

    /// Releases a claimed delivery when its SMTP job could not be enqueued.
    ///
    /// Releasing the claim does not consume an SMTP attempt and leaves the delivery available for later processing.
    ///
    /// - Parameters:
    ///   - emailDeliveryId: The identifier of the email delivery whose claim should be released.
    ///   - processingToken: The token proving ownership of the current processing lease.
    ///   - error: The queue dispatch error to persist for diagnostics.
    ///   - context: The execution context providing access to the database.
    /// - Throws: An error if the released state cannot be persisted.
    func releaseAfterDispatchFailure(emailDeliveryId: Int64,
                                     processingToken: String,
                                     error: Error,
                                     on context: ExecutionContext) async throws
}

/// Stores email deliveries and owns their processing state machine.
final class EmailDeliveryService: EmailDeliveryServiceType {
    private static let maximumAttempts = 3
    private static let processingLease: TimeInterval = 15 * 60
    private static let firstRetryDelay: TimeInterval = 5 * 60
    private static let secondRetryDelay: TimeInterval = 15 * 60
    private static let batchSize = 250

    private let currentDate: @Sendable () -> Date

    init(currentDate: @escaping @Sendable () -> Date = Date.init) {
        self.currentDate = currentDate
    }

    func create(_ email: EmailDto, on context: ExecutionContext) async throws -> Int64 {
        var storedEmail = email
        if storedEmail.from == nil {
            storedEmail.from = EmailAddressDto(address: context.application.settings.cached?.emailFromAddress ?? "",
                                               name: context.application.settings.cached?.emailFromName)
        }

        let emailDelivery = EmailDelivery(id: context.services.snowflakeService.generate(), email: storedEmail)
        try await emailDelivery.save(on: context.db)
        return try emailDelivery.requireID()
    }

    func createAndDispatch(_ email: EmailDto, on context: ExecutionContext) async throws {
        let emailDeliveryId = try await self.create(email, on: context)
        await self.dispatch(emailDeliveryId: emailDeliveryId, on: context)
    }

    func dispatch(emailDeliveryId: Int64, on context: ExecutionContext) async {
        do {
            try await context
                .queues(.emails)
                .dispatch(EmailSenderJob.self, EmailSenderJobDto(emailDeliveryId: emailDeliveryId))
        } catch {
            await context.logger.store("Cannot enqueue email delivery '\(emailDeliveryId)'.",
                                       error,
                                       on: context.application)
        }
    }

    func dispatchPending(on context: ExecutionContext) async throws {
        let emailDeliveryIds = try await self.pendingDeliveryIds(on: context)
        context.logger.info("Found \(emailDeliveryIds.count) email deliveries to enqueue.")

        for emailDeliveryId in emailDeliveryIds {
            await self.dispatch(emailDeliveryId: emailDeliveryId, on: context)
        }
    }

    func pendingDeliveryIds(on context: ExecutionContext) async throws -> [Int64] {
        let now = self.currentDate()
        let staleProcessingDate = now.addingTimeInterval(-Self.processingLease)

        return try await EmailDelivery.query(on: context.db)
            .filter(\.$attempts < Self.maximumAttempts)
            .group(.or) { group in
                group.filter(\.$status == .waiting)
                group.group(.and) { retryGroup in
                    retryGroup.filter(\.$status == .retryWaiting)
                    retryGroup.group(.or) { retryDateGroup in
                        retryDateGroup.filter(\.$nextAttemptAt == nil)
                        retryDateGroup.filter(\.$nextAttemptAt <= now)
                    }
                }
                group.group(.and) { processingGroup in
                    processingGroup.filter(\.$status == .processing)
                    processingGroup.group(.or) { processingDateGroup in
                        processingDateGroup.filter(\.$processingStartedAt == nil)
                        processingDateGroup.filter(\.$processingStartedAt <= staleProcessingDate)
                    }
                }
            }
            .sort(\.$createdAt, .ascending)
            .limit(Self.batchSize)
            .all(\.$id)
    }

    func prepareForSending(emailDeliveryId: Int64, on context: ExecutionContext) async throws -> EmailJobDto? {
        let now = self.currentDate()
        let staleProcessingDate = now.addingTimeInterval(-Self.processingLease)
        let processingToken = UUID().uuidString

        try await EmailDelivery.query(on: context.db)
            .filter(\.$id == emailDeliveryId)
            .filter(\.$attempts < Self.maximumAttempts)
            .group(.or) { group in
                group.filter(\.$status == .waiting)
                group.group(.and) { retryGroup in
                    retryGroup.filter(\.$status == .retryWaiting)
                    retryGroup.group(.or) { retryDateGroup in
                        retryDateGroup.filter(\.$nextAttemptAt == nil)
                        retryDateGroup.filter(\.$nextAttemptAt <= now)
                    }
                }
                group.group(.and) { processingGroup in
                    processingGroup.filter(\.$status == .processing)
                    processingGroup.group(.or) { processingDateGroup in
                        processingDateGroup.filter(\.$processingStartedAt == nil)
                        processingDateGroup.filter(\.$processingStartedAt <= staleProcessingDate)
                    }
                }
            }
            .set(\.$status, to: .processing)
            .set(\.$processingStartedAt, to: now)
            .set(\.$processingToken, to: processingToken)
            .set(\.$nextAttemptAt, to: nil)
            .update()

        guard let emailDelivery = try await EmailDelivery.query(on: context.db)
            .filter(\.$id == emailDeliveryId)
            .filter(\.$processingToken == processingToken)
            .first() else {
            return nil
        }

        return EmailJobDto(emailDeliveryId: emailDeliveryId,
                           processingToken: processingToken,
                           email: emailDelivery.emailDto())
    }

    func beginAttempt(emailDeliveryId: Int64,
                      processingToken: String,
                      on context: ExecutionContext) async throws -> EmailDeliveryAttempt? {
        let attemptToken = UUID().uuidString

        try await EmailDelivery.query(on: context.db)
            .filter(\.$id == emailDeliveryId)
            .filter(\.$status == .processing)
            .filter(\.$processingToken == processingToken)
            .filter(\.$attempts < Self.maximumAttempts)
            .set(\.$processingToken, to: attemptToken)
            .update()

        guard let emailDelivery = try await EmailDelivery.query(on: context.db)
            .filter(\.$id == emailDeliveryId)
            .filter(\.$processingToken == attemptToken)
            .first() else {
            return nil
        }

        emailDelivery.attempts += 1
        emailDelivery.lastAttemptAt = self.currentDate()
        try await emailDelivery.save(on: context.db)

        return EmailDeliveryAttempt(processingToken: attemptToken, attempts: emailDelivery.attempts)
    }

    func markSucceeded(emailDeliveryId: Int64,
                       processingToken: String,
                       on context: ExecutionContext) async throws {
        guard let emailDelivery = try await self.processingDelivery(emailDeliveryId: emailDeliveryId,
                                                                    processingToken: processingToken,
                                                                    on: context) else {
            return
        }

        emailDelivery.status = .succeeded
        emailDelivery.processingStartedAt = nil
        emailDelivery.processingToken = nil
        emailDelivery.nextAttemptAt = nil
        emailDelivery.errorMessage = nil
        emailDelivery.endedAt = self.currentDate()
        try await emailDelivery.save(on: context.db)
    }

    func markFailed(emailDeliveryId: Int64,
                    processingToken: String,
                    error: Error,
                    on context: ExecutionContext) async throws {
        guard let emailDelivery = try await self.processingDelivery(emailDeliveryId: emailDeliveryId,
                                                                    processingToken: processingToken,
                                                                    on: context) else {
            return
        }

        let shouldRetry = emailDelivery.attempts < Self.maximumAttempts
        emailDelivery.status = shouldRetry ? .retryWaiting : .permanentFailure
        emailDelivery.processingStartedAt = nil
        emailDelivery.processingToken = nil
        emailDelivery.nextAttemptAt = shouldRetry
            ? self.currentDate().addingTimeInterval(self.retryDelay(after: emailDelivery.attempts))
            : nil
        emailDelivery.errorMessage = self.errorMessage(for: error)
        emailDelivery.endedAt = shouldRetry ? nil : self.currentDate()
        try await emailDelivery.save(on: context.db)
    }

    func releaseAfterDispatchFailure(emailDeliveryId: Int64,
                                     processingToken: String,
                                     error: Error,
                                     on context: ExecutionContext) async throws {
        guard let emailDelivery = try await self.processingDelivery(emailDeliveryId: emailDeliveryId,
                                                                    processingToken: processingToken,
                                                                    on: context) else {
            return
        }

        let hasPreviousAttempt = emailDelivery.attempts > 0
        emailDelivery.status = hasPreviousAttempt ? .retryWaiting : .waiting
        emailDelivery.processingStartedAt = nil
        emailDelivery.processingToken = nil
        emailDelivery.nextAttemptAt = hasPreviousAttempt
            ? self.currentDate().addingTimeInterval(Self.firstRetryDelay)
            : nil
        emailDelivery.errorMessage = self.errorMessage(for: error)
        emailDelivery.endedAt = nil
        try await emailDelivery.save(on: context.db)
    }
}

private extension EmailDeliveryService {
    func processingDelivery(emailDeliveryId: Int64,
                            processingToken: String,
                            on context: ExecutionContext) async throws -> EmailDelivery? {
        try await EmailDelivery.query(on: context.db)
            .filter(\.$id == emailDeliveryId)
            .filter(\.$status == .processing)
            .filter(\.$processingToken == processingToken)
            .first()
    }

    func retryDelay(after attempts: Int) -> TimeInterval {
        attempts <= 1 ? Self.firstRetryDelay : Self.secondRetryDelay
    }

    func errorMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
