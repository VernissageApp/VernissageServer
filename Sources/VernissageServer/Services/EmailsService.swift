//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Smtp
import Queues

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

@_documentation(visibility: private)
protocol EmailsServiceType: Sendable {
    /// Configures the application SMTP server settings using the provided configuration values.
    ///
    /// - Parameters:
    ///   - hostName: The SMTP host address setting.
    ///   - port: The SMTP port setting.
    ///   - userName: The SMTP username setting.
    ///   - password: The SMTP password setting.
    ///   - secureMethod: The setting specifying the security protocol (e.g., SSL, TLS).
    ///   - application: The application context whose SMTP configuration will be updated.
    func setServerSettings(hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?, on application: Application)
    
    /// Dispatches a job to send a "forgot password" email to the specified user with a password reset link.
    ///
    /// - Parameters:
    ///   - user: The user who requested the password reset.
    ///   - redirectBaseUrl: The base URL for password reset links.
    ///   - request: The HTTP request context used for localization, queueing, and database access.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchForgotPasswordEmail(user: User, redirectBaseUrl: String, on request: Request) async throws
    
    /// Dispatches a job to send an account confirmation email to the specified user with a confirmation link.
    ///
    /// - Parameters:
    ///   - user: The user who needs to confirm their account.
    ///   - redirectBaseUrl: The base URL for email confirmation links.
    ///   - request: The HTTP request context used for localization, queueing, and database access.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchConfirmAccountEmail(user: User, redirectBaseUrl: String, on request: Request) async throws
    
    /// Dispatches a job to notify the user that their account archive is ready for download.
    ///
    /// - Parameters:
    ///   - archive: The archive object containing the user and file details.
    ///   - context: The execution context providing access to services and job queues.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchArchiveReadyEmail(archive: Archive, on context: ExecutionContext) async throws
    
    /// Dispatches a job to send a shared business card via email to a third party.
    ///
    /// - Parameters:
    ///   - sharedBusinessCard: The shared business card object containing recipient details.
    ///   - sharedCardUrl: The URL for accessing the shared card.
    ///   - context: The execution context providing access to services and job queues.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchSharedBusinessCardEmail(sharedBusinessCard: SharedBusinessCard, sharedCardUrl: String, on context: ExecutionContext) async throws
    
    /// Dispatches a job to send an approval notification email to the specified user.
    ///
    /// - Parameters:
    ///   - user: The user whose account has been approved.
    ///   - request: The HTTP request context used for localization, queueing, and database access.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchApproveAccountEmail(user: User, on request: Request) async throws
    
    /// Dispatches a job to send a rejection notification email to the specified user.
    ///
    /// - Parameters:
    ///   - user: The user whose account has been rejected.
    ///   - request: The HTTP request context used for localization, queueing, and database access.
    /// - Throws: An error if the email could not be dispatched or required data is missing.
    func dispatchRejectAccountEmail(user: User, on request: Request) async throws
}

/// A website for sending email messages.
final class EmailsService: EmailsServiceType {

    func setServerSettings(hostName: Setting?, port: Setting?, userName: Setting?, password: Setting?, secureMethod: Setting?, on application: Application) {
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
    
    func dispatchForgotPasswordEmail(user: User, redirectBaseUrl: String, on request: Request) async throws {
        guard let forgotPasswordGuid = user.forgotPasswordGuid else {
            throw ForgotPasswordError.tokenNotGenerated
        }

        let userName = user.getUserName()

        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw ForgotPasswordError.emailIsEmpty
        }
        
        let emailVariables = [
            "name": userName,
            "redirectBaseUrl": redirectBaseUrl.finished(with: "/"),
            "token": forgotPasswordGuid
        ]
        
        let localizablesService = request.application.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.forgotPassword.subject", locale: user.locale, on: request.db)
        let localizedEmailBody = try await localizablesService.get(code: "email.forgotPassword.body",
                                                                   locale: user.locale,
                                                                   variables: emailVariables,
                                                                   on: request.db)

        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, userName, redirectBaseUrl, forgotPasswordGuid)
        )
        
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }

    func dispatchConfirmAccountEmail(user: User, redirectBaseUrl: String, on request: Request) async throws {
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

        let emailVariables = [
            "name": userName,
            "redirectBaseUrl": redirectBaseUrl.finished(with: "/"),
            "token": emailConfirmationGuid,
            "userId": "\(userId)"
        ]
        
        let localizablesService = request.application.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.confirmEmail.subject", locale: user.locale, on: request.db)
        let localizedEmailBody = try await localizablesService.get(code: "email.confirmEmail.body",
                                                                   locale: user.locale,
                                                                   variables: emailVariables,
                                                                   on: request.db)
        
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, userName, redirectBaseUrl, emailConfirmationGuid, userId)
            )
            
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
    
    func dispatchArchiveReadyEmail(archive: Archive, on context: ExecutionContext) async throws {
        guard let emailAddress = archive.user.email, emailAddress.isEmpty == false else {
            throw ArchiveError.missingEmail
        }

        guard let fileName = archive.fileName else {
            throw ArchiveError.missingFileName
        }
        
        let userName = archive.user.getUserName()
        let emailAddressDto = EmailAddressDto(address: emailAddress, name: archive.user.name)
        
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let archiveUrl = baseImagesPath.finished(with: "/") + fileName

        let emailVariables = [
            "name": userName,
            "archiveUrl": archiveUrl
        ]
        
        let localizablesService = context.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.archiveReady.subject",
                                                                      locale: archive.user.locale,
                                                                      on: context.db)

        let localizedEmailBody = try await localizablesService.get(code: "email.archiveReady.body",
                                                                   locale: archive.user.locale,
                                                                   variables: emailVariables,
                                                                   on: context.db)
        
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, userName, archiveUrl)
            )
            
        try await context
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
    
    func dispatchSharedBusinessCardEmail(sharedBusinessCard: SharedBusinessCard, sharedCardUrl: String, on context: ExecutionContext) async throws {
        guard let emailAddress = sharedBusinessCard.thirdPartyEmail, emailAddress.isEmpty == false else {
            throw ArchiveError.missingEmail
        }
                
        let friendlyName = sharedBusinessCard.thirdPartyFriendlyName ?? ""
        let emailAddressDto = EmailAddressDto(address: emailAddress, name: sharedBusinessCard.thirdPartyName)

        let emailVariables = [
            "name": friendlyName,
            "cardUrl": sharedCardUrl
        ]
        
        let localizablesService = context.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.sharedBusinessCard.subject",
                                                                      locale: "en_US",
                                                                      on: context.db)

        let localizedEmailBody = try await localizablesService.get(code: "email.sharedBusinessCard.body",
                                                                   locale: "en_US",
                                                                   variables: emailVariables,
                                                                   on: context.db)
        
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, friendlyName, sharedCardUrl)
            )
            
        try await context
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
    
    func dispatchApproveAccountEmail(user: User, on request: Request) async throws {
        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw RegisterError.missingEmail
        }

        let userName = user.getUserName()
        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)

        let emailVariables = [
            "name": userName
        ]
        
        let localizablesService = request.application.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.approveAccount.subject", locale: user.locale, on: request.db)
        let localizedEmailBody = try await localizablesService.get(code: "email.approveAccount.body",
                                                                   locale: user.locale,
                                                                   variables: emailVariables,
                                                                   on: request.db)
        
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, userName)
            )
            
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
    
    func dispatchRejectAccountEmail(user: User, on request: Request) async throws {                
        guard let emailAddress = user.email, emailAddress.isEmpty == false else {
            throw RegisterError.missingEmail
        }

        let userName = user.getUserName()
        let emailAddressDto = EmailAddressDto(address: emailAddress, name: user.name)

        let emailVariables = [
            "name": userName
        ]
        
        let localizablesService = request.application.services.localizablesService
        let localizedEmailSubject = try await localizablesService.get(code: "email.rejectAccount.subject", locale: user.locale, on: request.db)
        let localizedEmailBody = try await localizablesService.get(code: "email.rejectAccount.body",
                                                                   locale: user.locale,
                                                                   variables: emailVariables,
                                                                   on: request.db)
        
        let email = EmailDto(to: emailAddressDto,
                             subject: localizedEmailSubject,
                             body: String(format: localizedEmailBody, userName)
            )
            
        try await request
            .queues(.emails)
            .dispatch(EmailJob.self, email, maxRetryCount: 3)
    }
}
