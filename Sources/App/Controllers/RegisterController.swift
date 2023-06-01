//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class RegisterController: RouteCollection {

    public static let uri: PathComponent = .constant("register")
    
    func boot(routes: RoutesBuilder) throws {
        let registerGroup = routes.grouped(RegisterController.uri)
        
        registerGroup
            .grouped(EventHandlerMiddleware(.registerNewUser, storeRequest: false))
            .post(use: newUser)
        
        registerGroup
            .grouped(EventHandlerMiddleware(.registerConfirm))
            .post("confirm", use: confirm)
        
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

        guard let captchaToken = registerUserDto.securityToken else {
            throw RegisterError.securityTokenIsMandatory
        }

        try await self.validateCaptcha(on: request, captchaToken: captchaToken)
        
        let usersService = request.application.services.usersService
        try await usersService.validateUserName(on: request, userName: registerUserDto.userName)
        try await usersService.validateEmail(on: request, email: registerUserDto.email)

        let user = try await self.createUser(on: request, registerUserDto: registerUserDto)
        try await self.sendNewUserEmail(on: request, user: user, redirectBaseUrl: registerUserDto.redirectBaseUrl)


        let response = try await self.createNewUserResponse(on: request, user: user)
        return response
    }

    /// New account (email) confirmation.
    func confirm(request: Request) async throws -> HTTPResponseStatus {
        let confirmEmailRequestDto = try request.content.decode(ConfirmEmailRequestDto.self)
        let usersService = request.application.services.usersService

        try await usersService.confirmEmail(on: request,
                                            userId: confirmEmailRequestDto.id,
                                            confirmationGuid: confirmEmailRequestDto.confirmationGuid)

        return HTTPStatus.ok
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

    private func validateCaptcha(on request: Request, captchaToken: String) async throws {
        let captchaService = request.application.services.captchaService
        let success = try await captchaService.validate(on: request, captchaFormResponse: captchaToken)
        if !success {
            throw RegisterError.securityTokenIsInvalid
        }
    }

    private func createUser(on request: Request, registerUserDto: RegisterUserDto) async throws -> User {

        let rolesService = request.application.services.rolesService
        let usersService = request.application.services.usersService

        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let domain = appplicationSettings?.domain ?? ""
        
        let salt = Password.generateSalt()
        let passwordHash = try Password.hash(registerUserDto.password, withSalt: salt)
        let emailConfirmationGuid = UUID.init().uuidString
        let gravatarHash = usersService.createGravatarHash(from: registerUserDto.email)
        
        let user = User(from: registerUserDto,
                        withPassword: passwordHash,
                        account: "\(registerUserDto.userName)@\(domain)",
                        salt: salt,
                        emailConfirmationGuid: emailConfirmationGuid,
                        gravatarHash: gravatarHash)

        try await user.save(on: request.db)

        let roles = try await rolesService.getDefault(on: request)
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
        try await emailsService.sendConfirmAccountEmail(on: request, user: user, redirectBaseUrl: redirectBaseUrl)
    }

    private func createNewUserResponse(on request: Request, user: User) async throws -> Response {
        let createdUserDto = UserDto(from: user)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(UsersController.uri)/@\(user.userName)")
        
        return try await createdUserDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}

