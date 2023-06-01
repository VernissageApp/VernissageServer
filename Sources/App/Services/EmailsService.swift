//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct EmailsServiceKey: StorageKey {
        typealias Value = EmailsServiceType
    }

    var emailsService: EmailsServiceType {
        get {
            self.application.storage[EmailsServiceKey.self] ?? EmailsService()
        }
        nonmutating set {
            self.application.storage[EmailsServiceKey.self] = newValue
        }
    }
}

protocol EmailsServiceType {
    func sendForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
    func sendConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
}

final class EmailsService: EmailsServiceType {

    func sendForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {

        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        guard let emailServiceAddress = appplicationSettings?.emailServiceAddress else {
            throw Abort(.internalServerError, reason: "Email service is not configured in database.")
        }

        guard let forgotPasswordGuid = user.forgotPasswordGuid else {
            throw ForgotPasswordError.tokenNotGenerated
        }

        let userName = user.getUserName()

        let emailServiceUri = URI(string: "\(emailServiceAddress)/emails/send")

        _ = try await request.client.post(emailServiceUri, beforeSend: { httpRequest in
            let emailAddress = EmailAddressDto(address: user.email, name: user.name)
            let email = EmailDto(to: emailAddress,
                                 subject: "Mikroservices - Forgot password",
                                 body: "<html><body><div>Hi \(userName),</div><div>You can reset your password by clicking following <a href='\(redirectBaseUrl)/reset-password?token=\(forgotPasswordGuid)'>link</a>.</div></body></html>")

            try httpRequest.content.encode(email)
        })
    }
    
    func sendConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {

        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        guard let emailServiceAddress = appplicationSettings?.emailServiceAddress else {
            throw Abort(.internalServerError, reason: "Email service is not configured in database.")
        }

        guard let userId = user.id else {
            throw RegisterError.userIdNotExists
        }

        let userName = user.getUserName()

        let emailServiceUri = URI(string: "\(emailServiceAddress)/emails/send")
        
        _ = try await request.client.post(emailServiceUri, beforeSend: { httpRequest in
            let emailAddress = EmailAddressDto(address: user.email, name: user.name)
            let email = EmailDto(to: emailAddress,
                                 subject: "Mikroservices - Confirm email",
                                 body: "<html><body><div>Hi \(userName),</div><div>Please confirm your account by clicking following <a href='\(redirectBaseUrl)/confirm-email?token=\(user.emailConfirmationGuid)&user=\(userId)'>link</a>.</div></body></html>")

            try httpRequest.content.encode(email)
        })
    }
}
