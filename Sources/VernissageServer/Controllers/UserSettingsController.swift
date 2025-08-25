//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Ink

extension UserSettingsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("user-settings")
    
    func boot(routes: RoutesBuilder) throws {
        let userSettingsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserSettingsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
                
        userSettingsGroup
            .grouped(EventHandlerMiddleware(.userSettingsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)

        userSettingsGroup
            .grouped(EventHandlerMiddleware(.userSettingsRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":key", use: read)
        
        userSettingsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.userSettingsSet))
            .grouped(CacheControlMiddleware(.noStore))
            .put(use: update)
        
        userSettingsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.userSettingsDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":key", use: delete)
    }
}

/// Controller for managing user settings.
///
/// Controller to manage basic user settings.
///
/// > Important: Base controller URL: `/api/v1/user-settings`.
struct UserSettingsController {

    /// Get all user settings.
    ///
    /// An endpoint that returns the user settings configured by user.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-settings`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-settings" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [
    ///     {
    ///         "key": "note-template",
    ///         "value": "My template"
    ///     },
    ///     {
    ///         "key": "hash-template",
    ///         "value": "Something"
    ///     },
    /// ]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: User settings.
    @Sendable
    func list(request: Request) async throws -> [UserSettingDto] {
        let authorizationPayloadId = try request.requireUserId()
        let userSettings = try await UserSetting.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .all()
        
        let userSettingDtos = userSettings.map {
            UserSettingDto(key: $0.key, value: $0.value)
        }
        
        return userSettingDtos
    }
    
    /// Get user setting by his key.
    ///
    /// An endpoint that returns the user setting configured by user.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-settings/:key`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-settings/note-template" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "key": "note-template",
    ///     "value": "My template"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: User settings.
    ///
    /// - Throws: `UserSettingError.keyIsRequired` if key is not specified.
    /// - Throws: `EntityNotFoundError.userSettingNotFound` if user setting not exists.
    @Sendable
    func read(request: Request) async throws -> UserSettingDto {
        let authorizationPayloadId = try request.requireUserId()
        
        guard let key = request.parameters.get("key") else {
            throw UserSettingError.keyIsRequired
        }
        
        guard let userSetting = try await UserSetting.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$key == key)
            .first() else {
            throw EntityNotFoundError.userSettingNotFound
        }
        
        return UserSettingDto(key: userSetting.key, value: userSetting.value)
    }
    
    /// Create or update user settings.
    ///
    /// An endpoint through which a user can create or update user settings.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-settings`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-settings" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "key": "note-template",
    ///     "value": "My template.."
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Changed user settings.
    @Sendable
    func update(request: Request) async throws -> UserSettingDto {
        let authorizationPayloadId = try request.requireUserId()
        let userSettingDto = try request.content.decode(UserSettingDto.self)

        let existingUserSetting = try await UserSetting.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$key == userSettingDto.key)
            .first()
        
        if let existingUserSetting {
            existingUserSetting.value = userSettingDto.value
            try await existingUserSetting.save(on: request.db)
            
            return UserSettingDto(key: existingUserSetting.key, value: existingUserSetting.value)
        } else {
            let id = request.application.services.snowflakeService.generate()
            let newUserSetting = UserSetting(id: id, userId: authorizationPayloadId, key: userSettingDto.key, value: userSettingDto.value)
            try await newUserSetting.save(on: request.db)
            
            return UserSettingDto(key: newUserSetting.key, value: newUserSetting.value)
        }
    }
    
    /// Delete user setting.
    ///
    /// An endpoint through which the user can remove an user setting.
    ///
    /// > Important: Endpoint URL: `/api/v1/user-settings/:key`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/user-settings/note-template" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `UserSettingError.keyIsRequired` if key is not specified.
    /// - Throws: `EntityNotFoundError.userSettingNotFound` if user setting not exists.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        let authorizationPayloadId = try request.requireUserId()

        guard let key = request.parameters.get("key") else {
            throw UserSettingError.keyIsRequired
        }
        
        let userSetting = try await UserSetting.query(on: request.db)
            .filter(\.$key == key)
            .filter(\.$user.$id == authorizationPayloadId)
            .first()
                
        guard let userSetting else {
            throw EntityNotFoundError.userSettingNotFound
        }
        
        try await userSetting.delete(on: request.db)
        return HTTPStatus.ok
    }
}
