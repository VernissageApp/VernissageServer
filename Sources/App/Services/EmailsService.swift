//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Smtp

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
    func setServerSettings(on application: Application, hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?)
    func dispatchForgotPasswordEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
    func dispatchConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws
}

final class EmailsService: EmailsServiceType {

    func setServerSettings(on application: Application, hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?) {
        application.smtp.configuration.hostname = hostName?.value ?? ""
        
        if let portValue = port?.value, let portInt = Int(portValue) {
            application.smtp.configuration.port = portInt
        } else {
            application.smtp.configuration.port = 467
        }
        
        application.smtp.configuration.signInMethod = .credentials(username: userName?.value ?? "",
                                                                   password: password?.value ?? "" )
        
        if secureMethod?.value == "none" {
            application.smtp.configuration.secure = .none
        } else if secureMethod?.value == "ssl" {
            application.smtp.configuration.secure = .ssl
        } else if secureMethod?.value == "startTls" {
            application.smtp.configuration.secure = .startTls
        } else if secureMethod?.value == "startTlsWhenAvailable" {
            application.smtp.configuration.secure = .startTlsWhenAvailable
        } else {
            application.smtp.configuration.secure = .ssl
        }
    }
    
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
        
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }

    func dispatchConfirmAccountEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        guard let userId = user.id else {
            throw RegisterError.userIdNotExists
        }
        
        guard let emailConfirmationGuid = user.emailConfirmationGuid else {
            throw RegisterError.missingEmailConfirmationGuid
        }
        
        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw RegisterError.missingEmail
        }

        let userName = user.getUserName()
        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)
        let email = EmailDto(to: emailAddressDto,
                             subject: "Vernissage - Confirm email",
                             body:
"""
<html>
    <body>
        <div>Hi \(userName),</div>
        <div>Please confirm your account by clicking following <a href='\(redirectBaseUrl)/confirm-email?token=\(emailConfirmationGuid)&user=\(userId)'>link</a>.</div>
    </body>
</html>
"""
            )
        
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
}
