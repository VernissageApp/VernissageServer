//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class ForgotPasswordController: RouteCollection {

    public static let uri: PathComponent = .constant("forgot")
    
    func boot(routes: RoutesBuilder) throws {
        let forgotGroup = routes.grouped(ForgotPasswordController.uri)

        forgotGroup
            .grouped(EventHandlerMiddleware(.forgotToken))
            .post("token", use: forgotPasswordToken)
        
        forgotGroup
            .grouped(EventHandlerMiddleware(.forgotConfirm, storeRequest: false))
            .post("confirm", use: forgotPasswordConfirm)
    }

    /// Forgot password.
    func forgotPasswordToken(request: Request) async throws -> HTTPResponseStatus {
        let forgotPasswordRequestDto = try request.content.decode(ForgotPasswordRequestDto.self)
        
        let usersService = request.application.services.usersService
        let emailsService = request.application.services.emailsService

        let user = try await usersService.forgotPassword(on: request, email: forgotPasswordRequestDto.email)

        try await emailsService.sendForgotPasswordEmail(on: request,
                                                  user: user,
                                                  redirectBaseUrl: forgotPasswordRequestDto.redirectBaseUrl)

        return HTTPStatus.ok
    }

    /// Changing password.
    func forgotPasswordConfirm(request: Request) async throws -> HTTPResponseStatus {
        let confirmationDto = try request.content.decode(ForgotPasswordConfirmationRequestDto.self)
        try ForgotPasswordConfirmationRequestDto.validate(content: request)

        let usersService = request.application.services.usersService
        try await usersService.confirmForgotPassword(
            on: request,
            forgotPasswordGuid: confirmationDto.forgotPasswordGuid,
            password: confirmationDto.password
        )

        return HTTPStatus.ok
    }
}
