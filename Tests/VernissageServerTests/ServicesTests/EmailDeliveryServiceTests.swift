//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Queues
import Testing
import Vapor

@Suite("EmailDeliveryService")
struct EmailDeliveryServiceTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Email snapshot should be stored with waiting status`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let service = EmailDeliveryService()
        let email = EmailDto(to: EmailAddressDto(address: "recipient@example.com", name: "Recipient"),
                             subject: "Stored subject",
                             body: "<p>Stored body</p>",
                             from: EmailAddressDto(address: "sender@example.com", name: "Sender"),
                             replyTo: EmailAddressDto(address: "reply@example.com", name: "Reply"))

        let emailDeliveryId = try await service.create(email, on: context)
        let storedEmailDelivery = try #require(try await EmailDelivery.find(emailDeliveryId, on: application.db))

        #expect(storedEmailDelivery.toAddress == "recipient@example.com")
        #expect(storedEmailDelivery.toName == "Recipient")
        #expect(storedEmailDelivery.fromAddress == "sender@example.com")
        #expect(storedEmailDelivery.fromName == "Sender")
        #expect(storedEmailDelivery.replyToAddress == "reply@example.com")
        #expect(storedEmailDelivery.replyToName == "Reply")
        #expect(storedEmailDelivery.subject == "Stored subject")
        #expect(storedEmailDelivery.body == "<p>Stored body</p>")
        #expect(storedEmailDelivery.status == .waiting)
        #expect(storedEmailDelivery.attempts == 0)
    }

    @Test
    func `Duplicate jobs should claim an email only once`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let service = EmailDeliveryService()
        let emailDeliveryId = try await service.create(self.email(), on: context)

        async let firstClaim = service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context)
        async let secondClaim = service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context)
        let claims = try await [firstClaim, secondClaim].compactMap { $0 }

        #expect(claims.count == 1)
        let storedEmailDelivery = try #require(try await EmailDelivery.find(emailDeliveryId, on: application.db))
        #expect(storedEmailDelivery.status == .processing)
        #expect(storedEmailDelivery.processingToken == claims.first?.processingToken)
    }

    @Test
    func `Duplicate SMTP jobs should begin an attempt only once`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let service = EmailDeliveryService()
        let emailDeliveryId = try await service.create(self.email(), on: context)
        let payload = try #require(try await service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context))

        async let firstAttempt = service.beginAttempt(emailDeliveryId: payload.emailDeliveryId,
                                                      processingToken: payload.processingToken,
                                                      on: context)
        async let secondAttempt = service.beginAttempt(emailDeliveryId: payload.emailDeliveryId,
                                                       processingToken: payload.processingToken,
                                                       on: context)
        let attempts = try await [firstAttempt, secondAttempt].compactMap { $0 }

        #expect(attempts.count == 1)
        let storedEmailDelivery = try #require(try await EmailDelivery.find(payload.emailDeliveryId, on: application.db))
        #expect(storedEmailDelivery.attempts == 1)
        #expect(storedEmailDelivery.processingToken == attempts.first?.processingToken)
    }

    @Test
    func `Successful attempt should finish an email delivery`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let currentDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = EmailDeliveryService(currentDate: { currentDate })
        let emailDeliveryId = try await service.create(self.email(), on: context)
        let payload = try #require(try await service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context))
        let attempt = try #require(try await service.beginAttempt(emailDeliveryId: payload.emailDeliveryId,
                                                                  processingToken: payload.processingToken,
                                                                  on: context))

        try await service.markSucceeded(emailDeliveryId: payload.emailDeliveryId,
                                        processingToken: attempt.processingToken,
                                        on: context)

        let storedEmailDelivery = try #require(try await EmailDelivery.find(payload.emailDeliveryId, on: application.db))
        #expect(storedEmailDelivery.status == .succeeded)
        #expect(storedEmailDelivery.attempts == 1)
        #expect(storedEmailDelivery.processingToken == nil)
        #expect(storedEmailDelivery.processingStartedAt == nil)
        #expect(storedEmailDelivery.nextAttemptAt == nil)
        #expect(storedEmailDelivery.errorMessage == nil)
        #expect(storedEmailDelivery.endedAt == currentDate)
    }

    @Test
    func `Temporary failure should stop after exactly three attempts`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let currentDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = EmailDeliveryService(currentDate: { currentDate })
        let emailDeliveryId = try await service.create(self.email(), on: context)

        for attemptNumber in 1...3 {
            let payload = try #require(try await service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context))
            let attempt = try #require(try await service.beginAttempt(emailDeliveryId: emailDeliveryId,
                                                                      processingToken: payload.processingToken,
                                                                      on: context))

            try await service.markFailed(emailDeliveryId: emailDeliveryId,
                                         processingToken: attempt.processingToken,
                                         error: TestEmailError.smtpUnavailable,
                                         on: context)

            let storedEmailDelivery = try #require(try await EmailDelivery.find(emailDeliveryId, on: application.db))
            #expect(storedEmailDelivery.attempts == attemptNumber)
            #expect(storedEmailDelivery.errorMessage == "SMTP unavailable")

            if attemptNumber < 3 {
                #expect(storedEmailDelivery.status == .retryWaiting)
                let nextAttemptAt = try #require(storedEmailDelivery.nextAttemptAt)
                let expectedDelay: TimeInterval = attemptNumber == 1 ? 5 * 60 : 15 * 60
                #expect(nextAttemptAt.timeIntervalSince(currentDate) == expectedDelay)
                #expect(storedEmailDelivery.endedAt == nil)

                storedEmailDelivery.nextAttemptAt = Date.distantPast
                try await storedEmailDelivery.save(on: application.db)
            } else {
                #expect(storedEmailDelivery.status == .permanentFailure)
                #expect(storedEmailDelivery.nextAttemptAt == nil)
                #expect(storedEmailDelivery.endedAt == currentDate)
            }
        }
    }

    @Test
    func `Queue dispatch failure should not consume a sending attempt`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let service = EmailDeliveryService()
        let emailDeliveryId = try await service.create(self.email(), on: context)
        let payload = try #require(try await service.prepareForSending(emailDeliveryId: emailDeliveryId, on: context))

        try await service.releaseAfterDispatchFailure(emailDeliveryId: payload.emailDeliveryId,
                                                      processingToken: payload.processingToken,
                                                      error: TestEmailError.queueUnavailable,
                                                      on: context)

        let storedEmailDelivery = try #require(try await EmailDelivery.find(payload.emailDeliveryId, on: application.db))
        #expect(storedEmailDelivery.status == .waiting)
        #expect(storedEmailDelivery.attempts == 0)
        #expect(storedEmailDelivery.processingToken == nil)
        #expect(storedEmailDelivery.processingStartedAt == nil)
        #expect(storedEmailDelivery.errorMessage == "Queue unavailable")
    }

    @Test
    func `Pending query should recover due and stale deliveries only`() async throws {
        let context = application.getQueueContext(queueName: .emails).executionContext
        let currentDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = EmailDeliveryService(currentDate: { currentDate })

        let waitingId = try await service.create(self.email(subject: "Waiting"), on: context)
        let retryDueId = try await service.create(self.email(subject: "Retry due"), on: context)
        let retryDue = try #require(try await EmailDelivery.find(retryDueId, on: application.db))
        retryDue.status = .retryWaiting
        retryDue.attempts = 1
        retryDue.nextAttemptAt = currentDate.addingTimeInterval(-1)
        try await retryDue.save(on: application.db)

        let retryFutureId = try await service.create(self.email(subject: "Retry future"), on: context)
        let retryFuture = try #require(try await EmailDelivery.find(retryFutureId, on: application.db))
        retryFuture.status = .retryWaiting
        retryFuture.attempts = 1
        retryFuture.nextAttemptAt = currentDate.addingTimeInterval(60)
        try await retryFuture.save(on: application.db)

        let staleProcessingId = try await service.create(self.email(subject: "Stale"), on: context)
        let staleProcessing = try #require(try await EmailDelivery.find(staleProcessingId, on: application.db))
        staleProcessing.status = .processing
        staleProcessing.processingStartedAt = currentDate.addingTimeInterval(-16 * 60)
        staleProcessing.processingToken = UUID().uuidString
        try await staleProcessing.save(on: application.db)

        let activeProcessingId = try await service.create(self.email(subject: "Active"), on: context)
        let activeProcessing = try #require(try await EmailDelivery.find(activeProcessingId, on: application.db))
        activeProcessing.status = .processing
        activeProcessing.processingStartedAt = currentDate.addingTimeInterval(-14 * 60)
        activeProcessing.processingToken = UUID().uuidString
        try await activeProcessing.save(on: application.db)

        let succeededId = try await service.create(self.email(subject: "Succeeded"), on: context)
        let succeeded = try #require(try await EmailDelivery.find(succeededId, on: application.db))
        succeeded.status = .succeeded
        succeeded.attempts = 1
        succeeded.endedAt = currentDate
        try await succeeded.save(on: application.db)

        let permanentFailureId = try await service.create(self.email(subject: "Permanent failure"), on: context)
        let permanentFailure = try #require(try await EmailDelivery.find(permanentFailureId, on: application.db))
        permanentFailure.status = .permanentFailure
        permanentFailure.attempts = 3
        permanentFailure.endedAt = currentDate
        try await permanentFailure.save(on: application.db)

        let pendingIds = try await service.pendingDeliveryIds(on: context)

        #expect(pendingIds.contains(waitingId))
        #expect(pendingIds.contains(retryDueId))
        #expect(pendingIds.contains(staleProcessingId))
        #expect(pendingIds.contains(retryFutureId) == false)
        #expect(pendingIds.contains(activeProcessingId) == false)
        #expect(pendingIds.contains(succeededId) == false)
        #expect(pendingIds.contains(permanentFailureId) == false)
    }

    private func email(subject: String = "Subject") -> EmailDto {
        EmailDto(to: EmailAddressDto(address: "recipient-\(UUID().uuidString)@example.com", name: "Recipient"),
                 subject: subject,
                 body: "<p>Body</p>",
                 from: EmailAddressDto(address: "sender@example.com", name: "Sender"),
                 replyTo: nil)
    }
}

private enum TestEmailError: LocalizedError {
    case smtpUnavailable
    case queueUnavailable

    var errorDescription: String? {
        switch self {
        case .smtpUnavailable:
            "SMTP unavailable"
        case .queueUnavailable:
            "Queue unavailable"
        }
    }
}
