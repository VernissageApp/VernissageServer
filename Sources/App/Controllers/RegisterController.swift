//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

/// Controller for adding new user into the system.
final class RegisterController: RouteCollection {

    public static let uri: PathComponent = .constant("register")
    
    func boot(routes: RoutesBuilder) throws {
        let registerGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(RegisterController.uri)
        
        registerGroup
            .grouped(EventHandlerMiddleware(.registerNewUser, storeRequest: false))
            .post(use: newUser)
        
        registerGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .get("username", ":name", use: isUserNameTaken)
        
        registerGroup
            .grouped(EventHandlerMiddleware(.registerEmail))
            .get("email", ":email", use: isEmailConnected)
    }

    /// Register new user.
    func newUser(request: Request) async throws -> Response {
        let registerUserDto = try request.content.decode(RegisterUserDto.self)
        try RegisterUserDto.validate(content: request)

        // Check if user agreed on server rules.
        guard registerUserDto.agreement == true else {
            throw RegisterError.userHaveToAcceptAgreement
        }
        
        // Check if registration is allowed.
        try await self.validateRegistrationOptions(on: request, registerUserDto: registerUserDto)
                
        // Validate recaptcha token.
        try await self.validateCaptcha(on: request, registerUserDto: registerUserDto)
        
        // Validate userName and email.
        let usersService = request.application.services.usersService
        try await usersService.validateUserName(on: request, userName: registerUserDto.userName)
        try await usersService.validateEmail(on: request, email: registerUserDto.email)
        
        // Save user in database.
        let user = try await self.createUser(on: request, registerUserDto: registerUserDto)
        
        // Send email with email confirmation message.
        try await self.sendNewUserEmail(on: request, user: user, redirectBaseUrl: registerUserDto.redirectBaseUrl)

        // When invitation token has been specified we have to mark it as used.
        if let inviteToken = registerUserDto.inviteToken {
            let invitationsService = request.application.services.invitationsService
            try await invitationsService.use(code: inviteToken, on: request.db, for: user)
        }
        
        // Send notification when new who needs approval registered.
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.isRegistrationOpened == false && applicationSettings?.isRegistrationByApprovalOpened == true {
            try await self.sendNotifications(user: user, on: request)
        }

        let flexiFields = try await user.$flexiFields.get(on: request.db)
        let response = try await self.createNewUserResponse(on: request, user: user, flexiFields: flexiFields)

        return response
    }

    /// User name verification.
    func isUserNameTaken(request: Request) async throws -> BooleanResponseDto {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let result = try await usersService.isUserNameTaken(on: request, userName: userName)

        return BooleanResponseDto(result: result)
    }

    /// Email verification.
    func isEmailConnected(request: Request) async throws -> BooleanResponseDto {

        guard let email = request.parameters.get("email") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let result = try await usersService.isEmailConnected(on: request, email: email)

        return BooleanResponseDto(result: result)
    }

    private func validateCaptcha(on request: Request, registerUserDto: RegisterUserDto) async throws {
        let applicationSettings = request.application.settings.cached

        if applicationSettings?.isRecaptchaEnabled == true {
            guard let captchaToken = registerUserDto.securityToken else {
                throw RegisterError.securityTokenIsMandatory
            }
            
            let captchaService = request.application.services.captchaService
            let success = try await captchaService.validate(on: request, captchaFormResponse: captchaToken)
            if !success {
                throw RegisterError.securityTokenIsInvalid
            }
        }
    }

    private func createUser(on request: Request, registerUserDto: RegisterUserDto) async throws -> User {

        let rolesService = request.application.services.rolesService
        let usersService = request.application.services.usersService
        
        let appplicationSettings = request.application.settings.cached
        let domain = appplicationSettings?.domain ?? ""
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let salt = Password.generateSalt()
        let passwordHash = try Password.hash(registerUserDto.password, withSalt: salt)
        let emailConfirmationGuid = UUID.init().uuidString
        let gravatarHash = usersService.createGravatarHash(from: registerUserDto.email)
        
        let (privateKey, publicKey) = try request.application.services.cryptoService.generateKeys()
        let isApproved = appplicationSettings?.isRegistrationOpened == true || appplicationSettings?.isRegistrationByInvitationsOpened == true
        
        let user = User(from: registerUserDto,
                        withPassword: passwordHash,
                        account: "\(registerUserDto.userName)@\(domain)",
                        activityPubProfile: "\(baseAddress)/actors/\(registerUserDto.userName)",
                        salt: salt,
                        emailConfirmationGuid: emailConfirmationGuid,
                        gravatarHash: gravatarHash,
                        isApproved: isApproved,
                        privateKey: privateKey,
                        publicKey: publicKey)

        try await user.save(on: request.db)

        let roles = try await rolesService.getDefault(on: request.db)
        await withThrowingTaskGroup(of: Void.self) { group in
            for role in roles {
                group.addTask {
                    try await user.$roles.attach(role, on: request.db)
                }
            }
        }

        return user
    }

    private func sendNewUserEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        let emailsService = request.application.services.emailsService
        try await emailsService.dispatchConfirmAccountEmail(on: request, user: user, redirectBaseUrl: redirectBaseUrl)
    }

    private func createNewUserResponse(on request: Request, user: User, flexiFields: [FlexiField]) async throws -> Response {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        var createdUserDto = UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        createdUserDto.email = user.email
        createdUserDto.emailWasConfirmed = user.emailWasConfirmed
        createdUserDto.locale = user.locale
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(UsersController.uri)/@\(user.userName)")
        
        return try await createdUserDto.encodeResponse(status: .created, headers: headers, for: request)
    }
    
    private func validateRegistrationOptions(on request: Request, registerUserDto: RegisterUserDto) async throws {
        let applicationSettings = request.application.settings.cached
        let invitationsService = request.application.services.invitationsService

        // All registration methods are disabled.
        guard applicationSettings?.isRegistrationOpened == true
                || applicationSettings?.isRegistrationByApprovalOpened == true
                || applicationSettings?.isRegistrationByInvitationsOpened == true else {
            throw RegisterError.registrationIsDisabled
        }
        
        // When registration is disabled we have to verify if other methods are enabled.
        if applicationSettings?.isRegistrationOpened == false {
            
            // If user specify invitation token and registration by invitations is opened.
            if let inviteToken = registerUserDto.inviteToken, inviteToken.isEmpty == false && applicationSettings?.isRegistrationByInvitationsOpened == true {
                // We have to find invitation by token.
                guard let invitation = try await invitationsService.get(by: inviteToken, on: request.db) else {
                    throw RegisterError.invitationTokenIsInvalid
                }
                
                // We have to check if ivitation token is not used already.
                guard invitation.$invited.id == nil else {
                    throw RegisterError.invitationTokenHasBeenUsed
                }

                // Invitation token has been found and it's not used.
                return
            }
            
            // If
            if (registerUserDto.reason ?? "").isEmpty == false && applicationSettings?.isRegistrationByApprovalOpened == true {
                // Nothing to do here. Moderator have to approve manually user registration.
                return
            }
            
            // User didn't specified token and reason (for him registration is not allowed).
            throw RegisterError.registrationIsDisabled
        }
    }
    
    private func sendNotifications(user: User, on request: Request) async throws {
        let notificationsService = request.application.services.notificationsService
        let usersService = request.application.services.usersService

        let moderators = try await usersService.getModerators(on: request.db)
        for moderator in moderators {
            try await notificationsService.create(type: .adminSignUp, to: moderator, by: user.requireID(), statusId: nil, on: request.db)
        }
    }
}
