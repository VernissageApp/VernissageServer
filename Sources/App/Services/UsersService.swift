//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol UsersServiceType {
    func count(on database: Database) async throws -> Int
    func get(on database: Database, userName: String) async throws -> User?
    func get(on database: Database, account: String) async throws -> User?
    func get(on database: Database, activityPubProfile: String) async throws -> User?
    func login(on request: Request, userNameOrEmail: String, password: String) async throws -> User
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
    func update(user: User, on database: Database, basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User
    func create(on database: Database, basedOn person: PersonDto, withAvatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User
    func delete(user: User, on database: Database) async throws
    func createGravatarHash(from email: String) -> String
    func search(query: String, on request: Request, page: Int, size: Int) async throws -> Page<User>
    func updateFollowCount(on database: Database, for userId: Int64) async throws
    func deleteFromRemote(userId: Int64, on: QueueContext) async throws
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
    func publicStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status>
}

final class UsersService: UsersServiceType {

    func count(on database: Database) async throws -> Int {
        return try await User.query(on: database).count()
    }
    
    func get(on database: Database, userName: String) async throws -> User? {
        let userNameNormalized = userName.uppercased()
        return try await User.query(on: database).filter(\.$userNameNormalized == userNameNormalized).first()
    }

    func get(on database: Database, account: String) async throws -> User? {
        let accountNormalized = account.uppercased()
        return try await User.query(on: database).filter(\.$accountNormalized == accountNormalized).first()
    }

    func get(on database: Database, activityPubProfile: String) async throws -> User? {
        let activityPubProfileNormalized = activityPubProfile.uppercased()
        return try await User.query(on: database).filter(\.$activityPubProfileNormalized == activityPubProfileNormalized).first()
    }
    
    func login(on request: Request, userNameOrEmail: String, password: String) async throws -> User {

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

        return user
    }
    
    func login(on request: Request, authenticateToken: String) async throws -> User {
        let externalUser = try await ExternalUser.query(on: request.db).with(\.$user)
            .filter(\.$authenticationToken == authenticateToken).first()
        
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

        return externalUser.user
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
    }
    
    func updateUser(on request: Request, userDto: UserDto, userNameNormalized: String) async throws -> User {
        let userFromDb = try await self.get(on: request.db, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        // Update filds in user entity.
        user.name = userDto.name
        user.bio = userDto.bio
        
        if let locale = userDto.locale {
            user.locale = locale
        }

        // Save user data.
        try await user.update(on: request.db)
        
        // Update flexi-fields.
        try await self.update(flexiFields: userDto.fields ?? [], on: request, for: user)
        
        // Update hashtags.
        try await self.update(hashtags: userDto.bio, on: request, for: user)
        
        return user
    }
    
    func update(user: User, on database: Database, basedOn person: PersonDto, withAvatarFileName avatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User {
        let remoteUserName = "\(person.preferredUsername)@\(person.url.host())"

        user.userName = remoteUserName
        user.account = remoteUserName
        user.name = person.name
        user.publicKey = person.publicKey.publicKeyPem
        user.manuallyApprovesFollowers = person.manuallyApprovesFollowers
        user.bio = person.summary
        user.avatarFileName = avatarFileName
        user.headerFileName = headerFileName
        user.sharedInbox = person.endpoints.sharedInbox
        user.userInbox = person.inbox
        user.userOutbox = person.outbox
        
        try await user.update(on: database)
        return user
    }
    
    func create(on database: Database, basedOn person: PersonDto, withAvatarFileName avatarFileName: String?, withHeaderFileName headerFileName: String?) async throws -> User {
        let remoteUserName = "\(person.preferredUsername)@\(person.url.host())"
        
        let user = User(isLocal: false,
                        userName: remoteUserName,
                        account: remoteUserName,
                        activityPubProfile: person.id,
                        name: person.name,
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
        
        try await user.save(on: database)

        return user
    }
    
    func delete(user: User, on database: Database) async throws {        
        try await user.delete(on: database)
    }
    
    func createGravatarHash(from email: String) -> String {
        let gravatarEmail = email.lowercased().trimmingCharacters(in: [" "])

        if let gravatarEmailData = gravatarEmail.data(using: .utf8) {
            return Insecure.MD5.hash(data: gravatarEmailData).hexEncodedString()
        }
        
        return ""
    }
    
    func search(query: String, on request: Request, page: Int, size: Int) async throws -> Page<User> {
        let queryNormalized = query.uppercased()

        return try await User.query(on: request.db)
            .filter(\.$queryNormalized ~~ queryNormalized)
            .sort(\.$followersCount, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    func ownStatuses(for userId: Int64, linkableParams: LinkableParams, on request: Request) async throws -> LinkableResult<Status> {
        var query = Status.query(on: request.db)
            .filter(\.$user.$id == userId)
            .filter(\.$reblog.$id == nil)
            .sort(\.$createdAt, .descending)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
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
    
    private func update(flexiFields: [FlexiFieldDto], on request: Request, for user: User) async throws {
        let flexiFieldsFromDb = try await user.$flexiFields.get(on: request.db)
        
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
                    
                    try await flexiFieldFromDb.update(on: request.db)
                }
            } else {
                // Remember what to delete.
                fieldsToDelete.append(flexiFieldFromDb)
            }
        }
        
        // Delete from database.
        try await fieldsToDelete.delete(on: request.db)
        
        // Add new flexi fields.
        for flexiFieldDto in flexiFields {
            if (flexiFieldDto.key ?? "") == "" && (flexiFieldDto.value ?? "") == "" {
                continue
            }
            
            if flexiFieldsFromDb.contains(where: { $0.stringId() == flexiFieldDto.id }) == false {
                let flexiField = try FlexiField(key: flexiFieldDto.key, value: flexiFieldDto.value, isVerified: false, userId: user.requireID())
                try await flexiField.save(on: request.db)
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
                let userHashtag = try UserHashtag(userId: user.requireID(), hashtag: tag)
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
}
