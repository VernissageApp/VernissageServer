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
    func dispatchForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
    func dispatchConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
}

final class EmailsService: EmailsServiceType {

    func dispatchForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        guard let forgotPasswordGuid = user.forgotPasswordGuid else {
            throw ForgotPasswordError.tokenNotGenerated
        }

        let userName = user.getUserName()

        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw ForgotPasswordError.emailIsEmpty
        }

        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)
        let email = EmailDto(to: emailAddressDto,
                             subject: "Vernissage - Forgot password",
                             body:
"""
<html>
    <body>
        <div>Hi \(userName),</div>
        <div>You can reset your password by clicking following <a href='\(redirectBaseUrl)/reset-password?token=\(forgotPasswordGuid)'>link</a>.</div>
    </body>
</html>
"""
        )
        
        try await request.queue.dispatch(EmailJob.self, email)
    }

    func dispatchConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        guard let userId = user.id else {
            throw RegisterError.userIdNotExists
        }

        let userName = user.getUserName()

        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw RegisterError.missingEmail
        }

        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)
        let email = EmailDto(to: emailAddressDto,
                             subject: "Mikroservices - Confirm email",
                             body:
"""
<html>
    <body>
        <div>Hi \(userName),</div>
        <div>Please confirm your account by clicking following <a href='\(redirectBaseUrl)/confirm-email?token=\(user.emailConfirmationGuid)&user=\(userId)'>link</a>.</div>
    </body>
</html>
"""
            )
        
        try await request.queue.dispatch(EmailJob.self, email)
    }
}
