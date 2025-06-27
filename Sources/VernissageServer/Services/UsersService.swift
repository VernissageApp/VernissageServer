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
    func count(sinceLastLoginDate: Date?, on database: Database) async throws -> Int
    func get(id: Int64, on database: Database) async throws -> User?
    func get(userName: String, on database: Database) async throws -> User?
    func get(account: String, on database: Database) async throws -> User?
    func get(activityPubProfile: String, on database: Database) async throws -> User?
    func getModerators(on database: Database) async throws -> [User]
    func getDefaultSystemUser(on database: Database) async throws -> User?
    func getPersonDto(for user: User, on context: ExecutionContext) async throws -> PersonDto
    func convertToDto(user: User, flexiFields: [FlexiField]?, roles: [Role]?, attachSensitive: Bool, attachFeatured: Bool, on context: ExecutionContext) async -> UserDto
    func convertToDtos(users: [User], attachSensitive: Bool, on context: ExecutionContext) async -> [UserDto]
    func login(userNameOrEmail: String, password: String, isMachineTrusted: Bool, on request: Request) async throws -> User
    func login(authenticateToken: String, on request: Request) async throws -> User
    func forgotPassword(email: String, on request: Request) async throws -> User
    func confirmForgotPassword(forgotPasswordGuid: String, password: String, on request: Request) async throws
    func changePassword(userId: Int64, currentPassword: String, newPassword: String, on request: Request) async throws
    func changeEmail(userId: Int64, email: String, on request: Request) async throws
    func confirmEmail(userId: Int64, confirmationGuid: String, on request: Request) async throws
    func isUserNameTaken(userName: String, on request: Request) async throws -> Bool
    func isEmailConnected(email: String, on request: Request) async throws -> Bool
    func isSignedInUser(userName: String, on request: Request) -> Bool
    func validateUserName(userName: String, on request: Request) async throws
    func validateEmail(email: String?, on request: Request) async throws
    func updateUser(userDto: UserDto, userNameNormalized: String, on context: ExecutionContext) async throws -> User
    func update(user: User, basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?, on context: ExecutionContext) async throws -> User
    func create(basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?, on context: ExecutionContext) async throws -> User
    func delete(user: User, force: Bool, on database: Database) async throws
    func delete(localUser userId: Int64, on context: QueueContext) async throws
    func delete(remoteUser: User, on database: Database) async throws
    func createGravatarHash(from email: String) -> String
    func updateFollowCount(for userId: Int64, on database: Database) async throws
    func deleteFromRemote(userId: Int64, on: QueueContext) async throws
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
    func publicStatuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status>
}

/// A service for managing users.
final class UsersService: UsersServiceType {

    func count(sinceLastLoginDate: Date?, on database: Database) async throws -> Int {
        var query = User.query(on: database)
            .filter(\.$isLocal == true)

        if let sinceLastLoginDate {
            query = query.filter(\.$lastLoginDate >= sinceLastLoginDate)
        }

        return try await query.count()
    }

    func get(id: Int64, on database: Database) async throws -> User? {
        return try await User.query(on: database)
            .filter(\.$id == id)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }
    
    func get(userName: String, on database: Database) async throws -> User? {
        let userNameNormalized = userName.uppercased()
        return try await User.query(on: database)
            .group(.or) { queryGroup in
                queryGroup.filter(\.$userNameNormalized == userNameNormalized)
                queryGroup.filter(\.$accountNormalized == userNameNormalized)
            }
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }

    func get(account: String, on database: Database) async throws -> User? {
        let accountNormalized = account.uppercased()
        return try await User.query(on: database)
            .filter(\.$accountNormalized == accountNormalized)
            .with(\.$flexiFields)
            .with(\.$roles)
            .first()
    }

    func get(activityPubProfile: String, on database: Database) async throws -> User? {
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
    
    func getPersonDto(for user: User, on context: ExecutionContext) async throws -> PersonDto {
        let appplicationSettings = context.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let attachments = try await user.$flexiFields.get(on: context.db)
        let hashtags = try await user.$hashtags.get(on: context.db)
        let aliases = try await user.$aliases.get(on: context.db)
        let published: String? = user.isLocal ? user.createdAt?.toISO8601String() : user.publishedAt?.toISO8601String()
        
        let personDto = PersonDto(id: user.activityPubProfile,
                                  following: "\(user.activityPubProfile)/following",
                                  followers: "\(user.activityPubProfile)/followers",
                                  inbox: "\(user.activityPubProfile)/inbox",
                                  outbox: "\(user.activityPubProfile)/outbox",
                                  preferredUsername: user.userName,
                                  name: user.name ?? user.userName,
                                  summary: user.bio ?? "",
                                  url: user.url ?? "\(baseAddress)/@\(user.userName)",
                                  alsoKnownAs: aliases.count > 0 ? aliases.map({ $0.activityPubProfile }) : nil,
                                  manuallyApprovesFollowers: user.manuallyApprovesFollowers,
                                  published: published,
                                  publicKey: PersonPublicKeyDto(id: "\(user.activityPubProfile)#main-key",
                                                                owner: user.activityPubProfile,
                                                                publicKeyPem: user.publicKey ?? ""),
                                  icon: self.getPersonImage(for: user.avatarFileName, on: context),
                                  image: self.getPersonImage(for: user.headerFileName, on: context),
                                  endpoints: PersonEndpointsDto(sharedInbox: "\(baseAddress)/shared/inbox"),
                                  attachment: attachments.map({ PersonAttachmentDto(name: $0.key ?? "",
                                                                                    value: $0.htmlValue(baseAddress: baseAddress)) }),
                                  tag: hashtags.map({ PersonHashtagDto(type: .hashtag, name: $0.hashtag, href: "\(baseAddress)/tags/\($0.hashtag)") })
        )
        
        return personDto
    }
    
    func convertToDto(user: User,
                      flexiFields: [FlexiField]?,
                      roles: [Role]?,
                      attachSensitive: Bool,
                      attachFeatured: Bool,
                      on context: ExecutionContext) async -> UserDto {
        let isFeatured = attachFeatured ? (try? await self.userIsFeatured(userId: user.requireID(), on: context)) : nil
        
        let userProfile = self.getUserProfile(user: user,
                                              flexiFields: flexiFields,
                                              roles: roles,
                                              attachSensitive: attachSensitive,
                                              isFeatured: isFeatured,
                                              on: context)
        return userProfile
    }
    
    func convertToDtos(users: [User], attachSensitive: Bool, on context: ExecutionContext) async -> [UserDto] {
        let userIds = users.compactMap { $0.id }
        let featuredUsers = try? await self.usersAreFeatured(userIds: userIds, on: context)

        let userDtos = await users.asyncMap { user in            
            let userProfile = self.getUserProfile(user: user,
                                                  flexiFields: user.flexiFields,
                                                  roles: user.roles,
                                                  attachSensitive: attachSensitive,
                                                  isFeatured: featuredUsers?.contains(where: { $0 == user.id }) ?? false,
                                                  on: context)
            return userProfile
        }
        
        return userDtos
    }
    
    func login(userNameOrEmail: String, password: String, isMachineTrusted: Bool, on request: Request) async throws -> User {

        let failedLoginsService = request.application.services.failedLoginsService
        let loginAttempsExceeded = try await failedLoginsService.loginAttempsExceeded(userName: userNameOrEmail, on: request)
        guard loginAttempsExceeded == false else {
            throw LoginError.loginAttemptsExceeded
        }
        
        let userNameOrEmailNormalized = userNameOrEmail.uppercased()
        let userFromDb = try await User.query(on: request.db).group(.or) { userNameGroup in
            userNameGroup.filter(\.$userNameNormalized == userNameOrEmailNormalized)
            userNameGroup.filter(\.$emailNormalized == userNameOrEmailNormalized)
        }.first()

        guard let user = userFromDb else {
            try await failedLoginsService.saveFailedLoginAttempt(userName: userNameOrEmail, on: request)
            throw LoginError.invalidLoginCredentials
        }
        
        guard let salt = user.salt else {
            throw LoginError.saltCorrupted
        }

        let passwordHash = try Password.hash(password, withSalt: salt)
        if user.password != passwordHash {
            try await failedLoginsService.saveFailedLoginAttempt(userName: userNameOrEmail, on: request)
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
    
    func login(authenticateToken: String, on request: Request) async throws -> User {
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

    func forgotPassword(email: String, on request: Request) async throws -> User {
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

    func confirmForgotPassword(forgotPasswordGuid: String, password: String, on request: Request) async throws {
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

    func changePassword(userId: Int64, currentPassword: String, newPassword: String, on request: Request) async throws {
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
    
    func changeEmail(userId: Int64, email: String, on request: Request) async throws {
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

    func confirmEmail(userId: Int64, confirmationGuid: String, on request: Request) async throws {
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

    func isUserNameTaken(userName: String, on request: Request) async throws -> Bool {

        let userNameNormalized = userName.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }

    func isEmailConnected(email: String, on request: Request) async throws -> Bool {

        let emailNormalized = email.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }
    
    func isSignedInUser(userName: String, on request: Request) -> Bool {
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userNameFromToken = request.userName

        let isProfileOwner = userNameFromToken.uppercased() == userNameNormalized
        guard isProfileOwner else {
            return false
        }
        
        return true
    }
    
    func validateUserName(userName: String, on request: Request) async throws {
        let userNameNormalized = userName.uppercased()
        let user = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if user != nil {
            throw RegisterError.userNameIsAlreadyTaken
        }
    }

    func validateEmail(email: String?, on request: Request) async throws {
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
    
    func updateUser(userDto: UserDto, userNameNormalized: String, on context: ExecutionContext) async throws -> User {
        let userFromDb = try await self.get(userName: userNameNormalized, on: context.db)

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
        try await user.update(on: context.db)
        
        // Update flexi-fields.
        try await self.update(flexiFields: userDto.fields ?? [], for: user, on: context)
        
        // Update hashtags.
        try await self.update(hashtags: userDto.bio, for: user, on: context)
        
        return user
    }
    
    func update(user: User,
                basedOn person: PersonDto,
                withAvatarFileName avatarFileName: String?,
                withHeaderFileName headerFileName: String?,
                on context: ExecutionContext) async throws -> User {

        let urls = person.url.values()
        guard let personUrl = urls.first else {
            throw PersonError.missingUrl
        }
        
        let remoteUserName = "\(person.preferredUsername)@\(personUrl.host)"

        user.url = personUrl
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
        user.publishedAt = person.published?.fromISO8601String()
        
        // Save user data.
        try await user.update(on: context.db)
        
        // Update flexi-fields
        if let flexiFieldsDto = person.attachment?.map({ FlexiFieldDto(key: $0.name, value: $0.value, baseAddress: "") }) {
            try await self.update(flexiFields: flexiFieldsDto, for: user, on: context)
        }
        
        return user
    }
    
    func create(basedOn person: PersonDto, withAvatarFileName avatarFileName: String?, withHeaderFileName headerFileName: String?, on context: ExecutionContext) async throws -> User {
        
        let urls = person.url.values()
        guard let personUrl = urls.first else {
            throw PersonError.missingUrl
        }
        
        let remoteUserName = "\(person.preferredUsername)@\(personUrl.host)"
        
        let newUserId = context.services.snowflakeService.generate()
        let user = User(id: newUserId,
                        type: person.getUserType(),
                        url: personUrl,
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
                        userOutbox: person.outbox,
                        publishedAt: person.published?.fromISO8601String()
        )
        
        // Save user to database.
        try await user.save(on: context.db)
        
        // Create flexi-fields
        if let flexiFieldsDto = person.attachment?.map({ FlexiFieldDto(key: $0.name, value: $0.value, baseAddress: "") }) {
            try await self.update(flexiFields: flexiFieldsDto, for: user, on: context)
        }
        
        return user
    }
    
    func delete(user: User, force: Bool, on database: Database) async throws {        
        try await user.delete(force: force, on: database)
    }
    
    func delete(localUser userId: Int64, on context: QueueContext) async throws {
        let statusesService = context.application.services.statusesService
        
        // We have to try to delete all user's statuses from local database.
        try? await statusesService.delete(owner: userId, on: context.executionContext)
        
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
            try await self.updateFollowCount(for: sourceId, on: context.application.db)
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
            try await self.updateFollowCount(for: sourceId, on: database)
        }
    }
    
    func createGravatarHash(from email: String) -> String {
        let gravatarEmail = email.lowercased().trimmingCharacters(in: [" "])

        if let gravatarEmailData = gravatarEmail.data(using: .utf8) {
            return Insecure.MD5.hash(data: gravatarEmailData).hexEncodedString()
        }
        
        return ""
    }
    
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status> {
        var query = Status.query(on: context.db)
            .filter(\.$user.$id == userId)
            .filter(\.$reblog.$id == nil)
            .filter(\.$replyToStatus.$id == nil)
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
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
    
    func publicStatuses(for userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<Status> {
        var query = Status.query(on: context.db)
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
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
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
    
    private func update(flexiFields: [FlexiFieldDto], for user: User, on context: ExecutionContext) async throws {
        let flexiFieldsFromDb = try await user.$flexiFields.get(on: context.db)
        
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
                    
                    try await flexiFieldFromDb.update(on: context.db)
                }
            } else {
                // Remember what to delete.
                fieldsToDelete.append(flexiFieldFromDb)
            }
        }
        
        // Delete from database.
        try await fieldsToDelete.delete(on: context.db)
        
        // Add new flexi fields.
        for flexiFieldDto in flexiFields {
            if (flexiFieldDto.key ?? "") == "" && (flexiFieldDto.value ?? "") == "" {
                continue
            }
            
            if flexiFieldsFromDb.contains(where: { $0.stringId() == flexiFieldDto.id }) == false {
                let id = context.services.snowflakeService.generate()
                let flexiField = try FlexiField(id: id,
                                                key: flexiFieldDto.key,
                                                value: flexiFieldDto.value,
                                                isVerified: false,
                                                userId: user.requireID())
                try await flexiField.save(on: context.db)
            }
        }
    }
    
    private func update(hashtags bio: String?, for user: User, on context: ExecutionContext) async throws {
        guard let bio else {
            try await user.$hashtags.get(on: context.db).delete(on: context.db)
            return
        }
                
        let hashtagPattern = #/(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        let matches = bio.matches(of: hashtagPattern)
        
        let tags = matches.map { match in
            String(match.tag.trimmingPrefix("#"))
        }
        
        let tagsFromDatabase = try await user.$hashtags.get(on: context.db)
        var tagsToDelete: [UserHashtag] = []
        
        for tagFromDatabase in tagsFromDatabase {
            if tags.first(where: { $0.uppercased() == tagFromDatabase.hashtagNormalized }) == nil {
                tagsToDelete.append(tagFromDatabase)
            }
        }
        
        // Delete from database.
        try await tagsToDelete.delete(on: context.db)
        
        // Add new hashtags.
        for tag in tags {
            if tag.isEmpty {
                continue
            }
            
            if tagsFromDatabase.contains(where: { $0.hashtagNormalized == tag.uppercased() }) == false {
                let userHashtagId = context.services.snowflakeService.generate()
                let userHashtag = try UserHashtag(id: userHashtagId, userId: user.requireID(), hashtag: tag)
                try await userHashtag.save(on: context.db)
            }
        }
    }
    
    func updateFollowCount(for userId: Int64, on database: Database) async throws {
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
                await context.logger.store("Sending user delete to shared inbox error.", error, on: context.application)
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
    
    private func getUserProfile(user: User,
                                flexiFields: [FlexiField]?,
                                roles: [Role]?,
                                attachSensitive: Bool,
                                isFeatured: Bool?,
                                on context: ExecutionContext) -> UserDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        var userDto = UserDto(from: user,
                              flexiFields: flexiFields,
                              roles: attachSensitive ? roles : nil,
                              baseImagesPath: baseImagesPath,
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
            userDto.lastLoginDate = user.lastLoginDate
        }

        return userDto
    }
    
    private func userIsFeatured(userId: Int64, on context: ExecutionContext) async throws -> Bool {
        let amount = try await FeaturedUser.query(on: context.db)
            .filter(\.$featuredUser.$id == userId)
            .count()
        
        return amount > 0
    }
    
    private func usersAreFeatured(userIds: [Int64], on context: ExecutionContext) async throws -> [Int64] {
        guard let authorizationPayloadId = context.userId else {
            return []
        }
        
        let featuredUsers = try await FeaturedUser.query(on: context.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$featuredUser.$id ~~ userIds)
            .field(\.$featuredUser.$id)
            .all()
        
        return featuredUsers.map({ $0.$featuredUser.id })
    }
    
    private func getPersonImage(for fileName: String?, on context: ExecutionContext) -> PersonImageDto? {
        guard let fileName else {
            return nil
        }
        
        let baseImagesPath = context.application.services.storageService.getBaseImagesPath(on: context)
        return PersonImageDto(mediaType: "image/jpeg",
                              url: "\(baseImagesPath)/\(fileName)")
    }
}
