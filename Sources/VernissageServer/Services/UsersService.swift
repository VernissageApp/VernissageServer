//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import FluentSQL
import RegexBuilder
import Queues

extension Application.Services {
    struct UsersServiceKey: StorageKey {
        typealias Value = UsersServiceType
    }

    var usersService: UsersServiceType {
        get {
            self.application.storage[UsersServiceKey.self] ?? UsersService()
        }
        nonmutating set {
            self.application.storage[UsersServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol UsersServiceType: Sendable {
    func count(on database: Database, sinceLastLoginDate: Date?) async throws -> Int
    func get(on database: Database, id: Int64) async throws -> User?
    func get(on database: Database, userName: String) async throws -> User?
    func get(on database: Database, account: String) async throws -> User?
    func get(on database: Database, activityPubProfile: String) async throws -> User?
    func getModerators(on database: Database) async throws -> [User]
    func getDefaultSystemUser(on database: Database) async throws -> User?
    func convertToDto(on request: Request, user: User, flexiFields: [FlexiField]?, roles: [Role]?, attachSensitive: Bool) async -> UserDto
    func convertToDtos(on request: Request, users: [User], attachSensitive: Bool) async -> [UserDto]
    func login(on request: Request, userNameOrEmail: String, password: String, isMachineTrusted: Bool) async throws -> User
    func login(on request: Request, authenticateToken: String) async throws -> User
    func forgotPassword(on request: Request, email: String) async throws -> User
    func confirmForgotPassword(on request: Request, forgotPasswordGuid: String, password: String) async throws
    func changePassword(on request: Request, userId: Int64, currentPassword: String, newPassword: String) async throws
    func changeEmail(on request: Request, userId: Int64, email: String) async throws
    func confirmEmail(on request: Request, userId: Int64, confirmationGuid: String) async throws
    func isUserNameTaken(on request: Request, userName: String) async throws -> Bool
    func isEmailConnected(on request: Request, email: String) async throws -> Bool
    func isSignedInUser(on request: Request, userName: String) -> Bool
    func validateUserName(on request: Request, userName: String) async throws
    func validateEmail(on request: Request, email: String?) async throws
    func updateUser(on request: Request, userDto: UserDto, userNameNormalized: String) async throws -> User
    func update(user: User, on application: Application, basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User
    func create(on application: Application, basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User
    func delete(user: User, force: Bool, on database: Database) async throws
    func delete(localUser userId: Int64, on context: QueueContext) async throws
    func delete(remoteUser: User, on database: Database) async throws
    func createGravatarHash(from email: String) -> String
    func updateFollowCount(on database: Database, for userId: Int64) async throws
    func deleteFromRemote(userId: Int64, on: QueueContext) async throws
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
    func publicStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
}

/// A service for managing users.
final class UsersService: UsersServiceType {

    func count(on database: Database, sinceLastLoginDate: Date?) async throws -> Int {
        var query = User.query(on: database)
            .filter(\.$isLocal == true)

        if let sinceLastLoginDate {
            query = query.filter(\.$lastLoginDate >= sinceLastLoginDate)
        }

        return try await query.count()
    }

    func get(on database: Database, id: Int64) async throws -> User? {
        return try await User.query(on: database)
            .filter(\.$id == id)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }
    
    func get(on database: Database, userName: String) async throws -> User? {
        let userNameNormalized = userName.uppercased()
        return try await User.query(on: database)
            .filter(\.$userNameNormalized == userNameNormalized)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }

    func get(on database: Database, account: String) async throws -> User? {
        let accountNormalized = account.uppercased()
        return try await User.query(on: database)
            .filter(\.$accountNormalized == accountNormalized)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }

    func get(on database: Database, activityPubProfile: String) async throws -> User? {
        let activityPubProfileNormalized = activityPubProfile.uppercased()
        return try await User.query(on: database)
            .filter(\.$activityPubProfileNormalized == activityPubProfileNormalized)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }
    
    func getModerators(on database: Database) async throws -> [User] {
        let moderators = try await User.query(on: database)
            .join(UserRole.self, on: \User.$id == \UserRole.$user.$id)
            .join(Role.self, on: \UserRole.$role.$id == \Role.$id)
            .group(.or) { queryGroup in
                queryGroup.filter(Role.self, \.$code == Role.administrator)
                queryGroup.filter(Role.self, \.$code == Role.moderator)
            }
            .unique()
            .all()
        
        return moderators.uniqued { user in user.id }
    }
    
    func convertToDto(on request: Request, user: User, flexiFields: [FlexiField]?, roles: [Role]?, attachSensitive: Bool) async -> UserDto {
        let isFeatured = try? await self.userIsFeatured(on: request, userId: user.requireID())
        
        let userProfile = self.getUserProfile(on: request,
                                                user: user,
                                                flexiFields: flexiFields,
                                                roles: roles,
                                                attachSensitive: attachSensitive,
                                                isFeatured: isFeatured ?? false)
        return userProfile
    }
    
    func convertToDtos(on request: Request, users: [User], attachSensitive: Bool) async -> [UserDto] {
        let userIds = users.compactMap { $0.id }
        let featuredUsers = try? await self.usersAreFeatured(on: request, userIds: userIds)

        let userDtos = await users.asyncMap { user in            
            let userProfile = self.getUserProfile(on: request,
                                                  user: user,
                                                  flexiFields: user.flexiFields,
                                                  roles: user.roles,
                                                  attachSensitive: attachSensitive,
                                                  isFeatured: featuredUsers?.contains(where: { $0 == user.id }) ?? false)
            return userProfile
        }
        
        return userDtos
    }
    
    func login(on request: Request, userNameOrEmail: String, password: String, isMachineTrusted: Bool) async throws -> User {

        let userNameOrEmailNormalized = userNameOrEmail.uppercased()

        let userFromDb = try await User.query(on: request.db).group(.or) { userNameGroup in
            userNameGroup.filter(\.$userNameNormalized == userNameOrEmailNormalized)
            userNameGroup.filter(\.$emailNormalized == userNameOrEmailNormalized)
        }.first()

        guard let user = userFromDb else {
            throw LoginError.invalidLoginCredentials
        }
        
        guard let salt = user.salt else {
            throw LoginError.saltCorrupted
        }

        let passwordHash = try Password.hash(password, withSalt: salt)
        if user.password != passwordHash {
            throw LoginError.invalidLoginCredentials
        }

        if user.isBlocked {
            throw LoginError.userAccountIsBlocked
        }
        
        if user.isApproved == false {
            throw LoginError.userAccountIsNotApproved
        }
        
        if user.twoFactorEnabled && isMachineTrusted == false {
            guard let token = request.headers.first(name: Constants.twoFactorTokenHeader) else {
                throw LoginError.twoFactorTokenNotFound
            }
            
            if token.isEmpty {
                throw LoginError.twoFactorTokenNotFound
            }
            
            let twoFactorTokensService = request.application.services.twoFactorTokensService
            guard let twoFactorToken = try await twoFactorTokensService.find(for: user.requireID(), on: request.db) else {
                throw EntityNotFoundError.twoFactorTokenNotFound
            }
            
            guard try twoFactorTokensService.validate(token, twoFactorToken: twoFactorToken, allowBackupCode: true) else {
                throw TwoFactorTokenError.tokenNotValid
            }
        }

        user.lastLoginDate = Date()
        try await user.save(on: request.db)
        
        return user
    }
    
    func login(on request: Request, authenticateToken: String) async throws -> User {
        let externalUser = try await ExternalUser
            .query(on: request.db)
            .with(\.$user)
            .filter(\.$authenticationToken == authenticateToken)
            .first()
        
        guard let externalUser = externalUser else {
            throw OpenIdConnectError.invalidAuthenticateToken
        }
        
        guard let tokenCreatedAt = externalUser.tokenCreatedAt else {
            throw OpenIdConnectError.authenticateTokenExpirationDateNotFound
        }
        
        if tokenCreatedAt.addingTimeInterval(60) < Date() {
            throw OpenIdConnectError.autheticateTokenExpired
        }

        if externalUser.user.isBlocked {
            throw OpenIdConnectError.userAccountIsBlocked
        }
        
        let user = externalUser.user

        user.lastLoginDate = Date()
        try await user.save(on: request.db)

        return user
    }

    func forgotPassword(on request: Request, email: String) async throws -> User {
        let emailNormalized = email.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        if user.isBlocked {
            throw ForgotPasswordError.userAccountIsBlocked
        }

        user.forgotPasswordGuid = UUID.init().uuidString
        user.forgotPasswordDate = Date()

        try await user.save(on: request.db)
        return user
    }

    func confirmForgotPassword(on request: Request, forgotPasswordGuid: String, password: String) async throws {
        let userFromDb = try await User.query(on: request.db).filter(\.$forgotPasswordGuid == forgotPasswordGuid).first()

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        if user.isBlocked {
            throw ForgotPasswordError.userAccountIsBlocked
        }

        guard let forgotPasswordDate = user.forgotPasswordDate else {
            throw ForgotPasswordError.tokenNotGenerated
        }

        let hoursDifference = Calendar.current.dateComponents([.hour], from: forgotPasswordDate, to: Date()).hour ?? 0
        if hoursDifference > 6 {
            throw ForgotPasswordError.tokenExpired
        }
                
        do {
            user.forgotPasswordGuid = nil
            user.forgotPasswordDate = nil
            user.emailWasConfirmed = true

            let salt = Password.generateSalt()

            user.salt = salt
            user.password = try Password.hash(password, withSalt: salt)
            
            try await user.save(on: request.db)
        } catch {
            throw ForgotPasswordError.passwordNotHashed
        }
    }

    func changePassword(on request: Request, userId: Int64, currentPassword: String, newPassword: String) async throws {
        let userFromDb = try await User.query(on: request.db).filter(\.$id == userId).first()

        guard let user = userFromDb else {
            throw ChangePasswordError.userNotFound
        }

        guard let salt = user.salt else {
            throw ChangePasswordError.saltCorrupted
        }
        
        let currentPasswordHash = try Password.hash(currentPassword, withSalt: salt)
        if user.password != currentPasswordHash {
            throw ChangePasswordError.invalidOldPassword
        }

        if user.emailWasConfirmed == false {
            throw ChangePasswordError.emailNotConfirmed
        }

        if user.isBlocked {
            throw ChangePasswordError.userAccountIsBlocked
        }

        let newSalt = Password.generateSalt()
        let newPasswordHash = try Password.hash(newPassword, withSalt: newSalt)

        user.password = newPasswordHash
        user.salt = newSalt

        try await user.update(on: request.db)
    }
    
    func changeEmail(on request: Request, userId: Int64, email: String) async throws {
        let userFromDb = try await User.find(userId, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        user.email = email
        user.emailNormalized = email.uppercased()
        user.emailWasConfirmed = false
        user.emailConfirmationGuid = UUID.init().uuidString
        
        try await user.update(on: request.db)
    }

    func confirmEmail(on request: Request, userId: Int64, confirmationGuid: String) async throws {
        let userFromDb = try await User.find(userId, on: request.db)

        guard let user = userFromDb else {
            throw ConfirmEmailError.invalidIdOrToken
        }

        guard user.emailConfirmationGuid == confirmationGuid else {
            throw ConfirmEmailError.invalidIdOrToken
        }

        user.emailWasConfirmed = true
        try await user.save(on: request.db)
    }

    func isUserNameTaken(on request: Request, userName: String) async throws -> Bool {

        let userNameNormalized = userName.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }

    func isEmailConnected(on request: Request, email: String) async throws -> Bool {

        let emailNormalized = email.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }
    
    func isSignedInUser(on request: Request, userName: String) -> Bool {
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userNameFromToken = request.userName

        let isProfileOwner = userNameFromToken.uppercased() == userNameNormalized
        guard isProfileOwner else {
            return false
        }
        
        return true
    }
    
    func validateUserName(on request: Request, userName: String) async throws {
        let userNameNormalized = userName.uppercased()
        let user = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if user != nil {
            throw RegisterError.userNameIsAlreadyTaken
        }
    }

    func validateEmail(on request: Request, email: String?) async throws {
        let emailNormalized = (email ?? "").uppercased()
        let user = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()
        if user != nil {
            throw RegisterError.emailIsAlreadyConnected
        }
        
        guard let emailDomain = emailNormalized.split(separator: "@").last else {
            return
        }
        
        let emailDomainString = String(emailDomain)
        let disposableEmail = try await DisposableEmail.query(on: request.db).filter(\.$domainNormalized == emailDomainString).first()
        if disposableEmail != nil {
            throw RegisterError.disposableEmailCannotBeUsed
        }
    }
    
    func updateUser(on request: Request, userDto: UserDto, userNameNormalized: String) async throws -> User {
        let userFromDb = try await self.get(on: request.db, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        // Update filds in user entity.
        user.name = userDto.name
        user.bio = userDto.bio
        user.manuallyApprovesFollowers = userDto.manuallyApprovesFollowers ?? false
        
        if let locale = userDto.locale {
            user.locale = locale
        }

        // Save user data.
        try await user.update(on: request.db)
        
        // Update flexi-fields.
        try await self.update(flexiFields: userDto.fields ?? [], on: request.application, for: user)
        
        // Update hashtags.
        try await self.update(hashtags: userDto.bio, on: request, for: user)
        
        return user
    }
    
    func update(user: User, on application: Application, basedOn person: PersonDto, withAvatarFileName avatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User {
        let remoteUserName = "\(person.preferredUsername)@\(person.url.host())"

        user.url = person.url
        user.userName = remoteUserName
        user.account = remoteUserName
        user.name = person.clearName()
        user.publicKey = person.publicKey.publicKeyPem
        user.manuallyApprovesFollowers = person.manuallyApprovesFollowers
        user.bio = person.summary
        user.avatarFileName = avatarFileName
        user.headerFileName = headerFileName
        user.sharedInbox = person.endpoints.sharedInbox
        user.userInbox = person.inbox
        user.userOutbox = person.outbox
        
        // Save user data.
        try await user.update(on: application.db)
        
        // Update flexi-fields
        if let flexiFieldsDto = person.attachment?.map({ FlexiFieldDto(key: $0.name, value: $0.value, baseAddress: "") }) {
            try await self.update(flexiFields: flexiFieldsDto, on: application, for: user)
        }
        
        return user
    }
    
    func create(on application: Application, basedOn person: PersonDto, withAvatarFileName avatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User {
        let remoteUserName = "\(person.preferredUsername)@\(person.url.host())"
        
        let newUserId = application.services.snowflakeService.generate()
        let user = User(id: newUserId,
                        url: person.url,
                        isLocal: false,
                        userName: remoteUserName,
                        account: remoteUserName,
                        activityPubProfile: person.id,
                        name: person.clearName(),
                        locale: "en_US",
                        publicKey: person.publicKey.publicKeyPem,
                        manuallyApprovesFollowers: person.manuallyApprovesFollowers,
                        bio: person.summary,
                        avatarFileName: avatarFileName,
                        isApproved: true,
                        headerFileName: headerFileName,
                        sharedInbox: person.endpoints.sharedInbox,
                        userInbox: person.inbox,
                        userOutbox: person.outbox
        )
        
        // Save user to database.
        try await user.save(on: application.db)
        
        // Create flexi-fields
        if let flexiFieldsDto = person.attachment?.map({ FlexiFieldDto(key: $0.name, value: $0.value, baseAddress: "") }) {
            try await self.update(flexiFields: flexiFieldsDto, on: application, for: user)
        }
        
        return user
    }
    
    func delete(user: User, force: Bool, on database: Database) async throws {        
        try await user.delete(force: force, on: database)
    }
    
    func delete(localUser userId: Int64, on context: QueueContext) async throws {
        let statusesService = context.application.services.statusesService
        
        // We have to try to delete all user's statuses from local database.
        try await statusesService.delete(owner: userId, on: context)
        
        // We have to delete all user's follows.
        let follows = try await Follow.query(on: context.application.db)
            .group(.or) { group in
                group
                    .filter(\.$target.$id == userId)
                    .filter(\.$source.$id == userId)
            }
            .all()
        let sourceIds = follows.map { $0.$source.id }
        
        // We have to delete all statuses featured by the user.
        let featuredStatuses = try await FeaturedStatus.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .all()
        
        // We have to delete user's notification marker.
        let notificationMarker = try await NotificationMarker.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .all()
        
        // We have to delete all user's notifications and notifications to other users.
        let notifications = try await Notification.query(on: context.application.db)
            .group(.or) { group in
                group
                    .filter(\.$user.$id == userId)
                    .filter(\.$byUser.$id == userId)
            }
            .all()
        
        // We have to delete notification markers which points to notification to delete.
        // Maybe in the future we can figure out something more clever.
        let notificationIds = try notifications.map { try $0.requireID() }
        let notificationMarkers = try await NotificationMarker.query(on: context.application.db)
            .filter(\.$notification.$id ~~ notificationIds)
            .all()
        
        // We have to delete all user's reports.
        let reports = try await Report.query(on: context.application.db)
            .group(.or) { group in
                group
                    .filter(\.$user.$id == userId)
                    .filter(\.$reportedUser.$id == userId)
            }
            .all()
        
        // We have to delete from trending user.
        let trendingUser = try await TrendingUser.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .all()
        
        // We have to delete all user's reports.
        let userMutes = try await UserMute.query(on: context.application.db)
            .group(.or) { group in
                group
                    .filter(\.$user.$id == userId)
                    .filter(\.$mutedUser.$id == userId)
            }
            .all()
        
        // We have to delete from user's timelines.
        let userStatuses = try await UserStatus.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .all()
        
        // We have to delete user's aliases.
        let userAliases = try await UserAlias.query(on: context.application.db)
            .filter((\.$user.$id == userId))
            .all()
        
        // We have to delete user's bookmarks.
        let statusBookmarks = try await StatusBookmark.query(on: context.application.db)
            .filter((\.$user.$id == userId))
            .all()
        
        // We have to delete user's favourited statuses.
        let statusFavourites = try await StatusFavourite.query(on: context.application.db)
            .filter((\.$user.$id == userId))
            .all()

        // We have to delete user's blocked domains.
        let userBlockedDomains = try await UserBlockedDomain.query(on: context.application.db)
            .filter((\.$user.$id == userId))
            .all()
        
        try await context.application.db.transaction { transaction in
            try await userAliases.delete(on: transaction)
            try await follows.delete(on: transaction)
            try await notificationMarker.delete(on: transaction)
            try await notificationMarkers.delete(on: transaction)
            try await notifications.delete(on: transaction)
            try await reports.delete(on: transaction)
            try await trendingUser.delete(on: transaction)
            try await userMutes.delete(on: transaction)
            try await userStatuses.delete(on: transaction)
            try await featuredStatuses.delete(on: transaction)
            try await statusBookmarks.delete(on: transaction)
            try await statusFavourites.delete(on: transaction)
            try await userBlockedDomains.delete(on: transaction)
        }
        
        // Recalculate user's follows count.
        try await sourceIds.asyncForEach { sourceId in
            try await self.updateFollowCount(on: context.application.db, for: sourceId)
        }
    }
    
    func delete(remoteUser: User, on database: Database) async throws {
        let remoteUserId = try remoteUser.requireID()

        let follows = try await Follow.query(on: database)
            .filter(\.$target.$id == remoteUserId)
            .all()
        let sourceIds = follows.map({ $0.$source.id })
        
        // We have to delete all user's reports.
        let reports = try await Report.query(on: database)
            .group(.or) { group in
                group
                    .filter(\.$user.$id == remoteUserId)
                    .filter(\.$reportedUser.$id == remoteUserId)
            }
            .all()
        
        // We have to delete from trending user.
        let trendingUser = try await TrendingUser.query(on: database)
            .filter(\.$user.$id == remoteUserId)
            .all()
        
        // We have to delete all user's reports.
        let userMutes = try await UserMute.query(on: database)
            .group(.or) { group in
                group
                    .filter(\.$user.$id == remoteUserId)
                    .filter(\.$mutedUser.$id == remoteUserId)
            }
            .all()
        
        try await database.transaction { transaction in
            try await follows.delete(on: transaction)
            try await reports.delete(on: transaction)
            try await trendingUser.delete(on: transaction)
            try await userMutes.delete(on: transaction)
            try await remoteUser.delete(force: true, on: transaction)
        }
        
        try await sourceIds.asyncForEach { sourceId in
            try await self.updateFollowCount(on: database, for: sourceId)
        }
    }
    
    func createGravatarHash(from email: String) -> String {
        let gravatarEmail = email.lowercased().trimmingCharacters(in: [" "])

        if let gravatarEmailData = gravatarEmail.data(using: .utf8) {
            return Insecure.MD5.hash(data: gravatarEmailData).hexEncodedString()
        }
        
        return ""
    }
    
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status> {
        var query = Status.query(on: request.db)
            .filter(\.$user.$id == userId)
            .filter(\.$reblog.$id == nil)
            .filter(\.$replyToStatus.$id == nil)
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$user)
            .with(\.$category)
            
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        } else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        } else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()
        
        return LinkableResult(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statuses
        )
    }
    
    func publicStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status> {
        var query = Status.query(on: request.db)
            .filter(\.$replyToStatus.$id == nil)
            .group(.and) { group in
                group
                    .filter(\.$visibility ~~ [.public])
                    .filter(\.$user.$id == userId)
                    .filter(\.$reblog.$id == nil)
            }
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$user)
            .with(\.$category)
            
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        } else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        } else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }

        let statuses = try await query
            .limit(linkableParams.limit)
            .all()
        
        return LinkableResult(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statuses
        )
    }
    
    private func update(flexiFields: [FlexiFieldDto], on application: Application, for user: User) async throws {
        let flexiFieldsFromDb = try await user.$flexiFields.get(on: application.db)
        
        var fieldsToDelete: [FlexiField] = []
        for flexiFieldFromDb in flexiFieldsFromDb {
            if let flexiFieldDto = flexiFields.first(where: { $0.id == flexiFieldFromDb.stringId() }) {
                if (flexiFieldDto.key ?? "") == "" && (flexiFieldDto.value ?? "") == "" {
                    // User cleared key and value thus we can delete the whole row.
                    fieldsToDelete.append(flexiFieldFromDb)
                } else {
                    // Update existing one.
                    flexiFieldFromDb.key = flexiFieldDto.key
                    flexiFieldFromDb.value = flexiFieldDto.value
                    flexiFieldFromDb.isVerified = false
                    
                    try await flexiFieldFromDb.update(on: application.db)
                }
            } else {
                // Remember what to delete.
                fieldsToDelete.append(flexiFieldFromDb)
            }
        }
        
        // Delete from database.
        try await fieldsToDelete.delete(on: application.db)
        
        // Add new flexi fields.
        for flexiFieldDto in flexiFields {
            if (flexiFieldDto.key ?? "") == "" && (flexiFieldDto.value ?? "") == "" {
                continue
            }
            
            if flexiFieldsFromDb.contains(where: { $0.stringId() == flexiFieldDto.id }) == false {
                let id = application.services.snowflakeService.generate()
                let flexiField = try FlexiField(id: id,
                                                key: flexiFieldDto.key,
                                                value: flexiFieldDto.value,
                                                isVerified: false,
                                                userId: user.requireID())
                try await flexiField.save(on: application.db)
            }
        }
    }
    
    private func update(hashtags bio: String?, on request: Request, for user: User) async throws {
        guard let bio else {
            try await user.$hashtags.get(on: request.db).delete(on: request.db)
            return
        }
                
        let hashtagPattern = #/(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        let matches = bio.matches(of: hashtagPattern)
        
        let tags = matches.map { match in
            String(match.tag.trimmingPrefix("#"))
        }
        
        let tagsFromDatabase = try await user.$hashtags.get(on: request.db)
        var tagsToDelete: [UserHashtag] = []
        
        for tagFromDatabase in tagsFromDatabase {
            if tags.first(where: { $0.uppercased() == tagFromDatabase.hashtagNormalized }) == nil {
                tagsToDelete.append(tagFromDatabase)
            }
        }
        
        // Delete from database.
        try await tagsToDelete.delete(on: request.db)
        
        // Add new hashtags.
        for tag in tags {
            if tag.isEmpty {
                continue
            }
            
            if tagsFromDatabase.contains(where: { $0.hashtagNormalized == tag.uppercased() }) == false {
                let userHashtagId = request.application.services.snowflakeService.generate()
                let userHashtag = try UserHashtag(id: userHashtagId, userId: user.requireID(), hashtag: tag)
                try await userHashtag.save(on: request.db)
            }
        }
    }
    
    func updateFollowCount(on database: Database, for userId: Int64) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "followersCount") = (SELECT count(1) FROM \(ident: Follow.schema) WHERE \(ident: "targetId") = \(bind: userId)),
                \(ident: "followingCount") = (SELECT count(1) FROM \(ident: Follow.schema) WHERE \(ident: "sourceId") = \(bind: userId))
            WHERE \(ident: "id") = \(bind: userId)
        """).run()
    }
    
    func deleteFromRemote(userId: Int64, on context: QueueContext) async throws {
        guard let userToDelete = try await User.query(on: context.application.db)
            .withDeleted()
            .filter(\.$id == userId)
            .first() else {
            context.logger.warning("User: '\(userId)' cannot exists in database.")
            return
        }

        guard userToDelete.isLocal else {
            context.logger.warning("User: '\(userId)' doesn't have to be deleted from remote server (it's remote user).")
            return
        }
        
        guard let privateKey = userToDelete.privateKey else {
            context.logger.warning("User: '\(userId)' cannot be send to shared inbox (delete). Missing private key.")
            return
        }
        
        let users = try await User.query(on: context.application.db)
            .filter(\.$isLocal == false)
            .field(\.$sharedInbox)
            .unique()
            .all()
        
        let sharedInboxes = users.map({  $0.sharedInbox })
        for (index, sharedInbox) in sharedInboxes.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("User delete: '\(userToDelete.userName)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxes.count)] Sending user delete: '\(userToDelete.userName)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                try await activityPubClient.delete(actorId: userToDelete.activityPubProfile, on: sharedInboxUrl)
            } catch {
                context.logger.error("Sending user delete to shared inbox error: \(error.localizedDescription)")
            }
        }
    }
    
    func getDefaultSystemUser(on database: Database) async throws -> User? {
        guard let systemDefaultUserIdSetting = try await Setting.query(on: database)
            .filter(\.$key == SettingKey.systemDefaultUserId.rawValue)
            .first() else {
            return nil
        }
        
        if systemDefaultUserIdSetting.value == "" {
            return nil
        }
        
        guard let systemUserId = systemDefaultUserIdSetting.value.toId() else {
            return nil
        }
        
        return try await User.query(on: database).filter(\.$id == systemUserId).first()
    }
    
    private func getUserProfile(on request: Request, user: User, flexiFields: [FlexiField]?, roles: [Role]?, attachSensitive: Bool, isFeatured: Bool) -> UserDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        var userDto = UserDto(from: user,
                              flexiFields: flexiFields,
                              roles: attachSensitive ? roles : nil,
                              baseStoragePath: baseStoragePath,
                              baseAddress: baseAddress,
                              featured: isFeatured)

        if attachSensitive {
            userDto.email = user.email
            userDto.emailWasConfirmed = user.emailWasConfirmed
            userDto.locale = user.locale
            userDto.isBlocked = user.isBlocked
            userDto.isApproved = user.isApproved
            userDto.twoFactorEnabled = user.twoFactorEnabled
            userDto.manuallyApprovesFollowers = user.manuallyApprovesFollowers
        }

        return userDto
    }
    
    private func userIsFeatured(on request: Request, userId: Int64) async throws -> Bool {        
        let amount = try await FeaturedUser.query(on: request.db)
            .filter(\.$featuredUser.$id == userId)
            .count()
        
        return amount > 0
    }
    
    private func usersAreFeatured(on request: Request, userIds: [Int64]) async throws -> [Int64] {
        guard let authorizationPayloadId = request.userId else {
            return []
        }
        
        let featuredUsers = try await FeaturedUser.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$featuredUser.$id ~~ userIds)
            .field(\.$featuredUser.$id)
            .all()
        
        return featuredUsers.map({ $0.$featuredUser.id })
    }
}
