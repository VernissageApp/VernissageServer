//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Foundation

/// Persistent snapshot of an email and its delivery state.
final class EmailDelivery: Model, @unchecked Sendable {
    static let schema = "EmailDeliveries"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "toAddress")
    var toAddress: String

    @Field(key: "toName")
    var toName: String?

    @Field(key: "fromAddress")
    var fromAddress: String

    @Field(key: "fromName")
    var fromName: String?

    @Field(key: "replyToAddress")
    var replyToAddress: String?

    @Field(key: "replyToName")
    var replyToName: String?

    @Field(key: "subject")
    var subject: String

    @Field(key: "body")
    var body: String

    @Field(key: "status")
    var status: EmailDeliveryStatus

    @Field(key: "attempts")
    var attempts: Int

    @Timestamp(key: "nextAttemptAt", on: .none)
    var nextAttemptAt: Date?

    @Timestamp(key: "lastAttemptAt", on: .none)
    var lastAttemptAt: Date?

    @Timestamp(key: "processingStartedAt", on: .none)
    var processingStartedAt: Date?

    @Field(key: "processingToken")
    var processingToken: String?

    @Timestamp(key: "endedAt", on: .none)
    var endedAt: Date?

    @Field(key: "errorMessage")
    var errorMessage: String?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, email: EmailDto) {
        self.init()

        self.id = id
        self.toAddress = email.to.address
        self.toName = email.to.name
        self.fromAddress = email.from?.address ?? ""
        self.fromName = email.from?.name
        self.replyToAddress = email.replyTo?.address
        self.replyToName = email.replyTo?.name
        self.subject = email.subject
        self.body = email.body
        self.status = .waiting
        self.attempts = 0
    }

    func emailDto() -> EmailDto {
        let replyTo = self.replyToAddress.map { EmailAddressDto(address: $0, name: self.replyToName) }

        return EmailDto(to: EmailAddressDto(address: self.toAddress, name: self.toName),
                        subject: self.subject,
                        body: self.body,
                        from: EmailAddressDto(address: self.fromAddress, name: self.fromName),
                        replyTo: replyTo)
    }
}
