//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// System user.
final class User: Model, @unchecked Sendable {

    static let schema = "Users"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "isLocal")
    var isLocal: Bool
    
    @Field(key: "userName")
    var userName: String
    
    @Field(key: "account")
    var account: String

    @Field(key: "activityPubProfile")
    var activityPubProfile: String
    
    @Field(key: "email")
    var email: String?
    
    @Field(key: "name")
    var name: String?
    
    @Field(key: "password")
    var password: String?
    
    @Field(key: "salt")
    var salt: String?
    
    @Field(key: "emailWasConfirmed")
    var emailWasConfirmed: Bool?
    
    @Field(key: "isBlocked")
    var isBlocked: Bool
    
    @Field(key: "locale")
    var locale: String
    
    @Field(key: "emailConfirmationGuid")
    var emailConfirmationGuid: String?
    
    @Field(key: "forgotPasswordGuid")
    var forgotPasswordGuid: String?
    
    @Field(key: "forgotPasswordDate")
    var forgotPasswordDate: Date?
    
    @Field(key: "bio")
    var bio: String?
    
    @Field(key: "userNameNormalized")
    var userNameNormalized: String

    @Field(key: "accountNormalized")
    var accountNormalized: String
    
    @Field(key: "emailNormalized")
    var emailNormalized: String?
    
    @Field(key: "activityPubProfileNormalized")
    var activityPubProfileNormalized: String
    
    @Field(key: "gravatarHash")
    var gravatarHash: String?
    
    @Field(key: "privateKey")
    var privateKey: String?

    @Field(key: "publicKey")
    var publicKey: String?
    
    @Field(key: "avatarFileName")
    var avatarFileName: String?
    
    @Field(key: "manuallyApprovesFollowers")
    var manuallyApprovesFollowers: Bool
    
    @Field(key: "reason")
    var reason: String?
    
    @Field(key: "isApproved")
    var isApproved: Bool
    
    @Field(key: "headerFileName")
    var headerFileName: String?
    
    @Field(key: "statusesCount")
    var statusesCount: Int
    
    @Field(key: "followersCount")
    var followersCount: Int
    
    @Field(key: "followingCount")
    var followingCount: Int

    @Field(key: "sharedInbox")
    var sharedInbox: String?

    @Field(key: "userInbox")
    var userInbox: String?
    
    @Field(key: "userOutbox")
    var userOutbox: String?
    
    @Field(key: "queryNormalized")
    var queryNormalized: String
    
    @Field(key: "lastLoginDate")
    var lastLoginDate: Date?
    
    @Field(key: "twoFactorEnabled")
    var twoFactorEnabled: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deletedAt", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$user)
    var refreshTokens: [RefreshToken]
    
    @Children(for: \.$source)
    var following: [Follow]
    
    @Children(for: \.$target)
    var follows: [Follow]
    
    @Children(for: \.$user)
    var flexiFields: [FlexiField]

    @Children(for: \.$user)
    var hashtags: [UserHashtag]

    @Children(for: \.$user)
    var statuses: [Status]
    
    @Siblings(through: UserRole.self, from: \.$user, to: \.$role)
    var roles: [Role]
    
    @OptionalChild(for: \.$user)
    var twoFactorToken: TwoFactorToken?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }
    
    convenience init(id: Int64? = nil,
                     isLocal: Bool,
                     userName: String,
                     account: String,
                     activityPubProfile: String,
                     email: String? = nil,
                     name: String? = nil,
                     password: String? = nil,
                     salt: String? = nil,
                     emailWasConfirmed: Bool? = nil,
                     isBlocked: Bool = false,
                     locale: String,
                     emailConfirmationGuid: String? = nil,
                     gravatarHash: String? = nil,
                     privateKey: String? = nil,
                     publicKey: String? = nil,
                     manuallyApprovesFollowers: Bool = false,
                     forgotPasswordGuid: String? = nil,
                     forgotPasswordDate: Date? = nil,
                     bio: String? = nil,
                     avatarFileName: String? = nil,
                     reason: String? = nil,
                     isApproved: Bool,
                     headerFileName: String? = nil,
                     statusesCount: Int = 0,
                     followersCount: Int = 0,
                     followingCount: Int = 0,
                     sharedInbox: String? = nil,
                     userInbox: String? = nil,
                     userOutbox: String? = nil,
                     twoFactorEnabled: Bool = false
    ) {
        self.init()

        self.isLocal = isLocal
        self.userName = userName
        self.account = account
        self.activityPubProfile = activityPubProfile
        self.email = email
        self.name = name
        self.password = password
        self.salt = salt
        self.emailWasConfirmed = emailWasConfirmed
        self.isBlocked = isBlocked
        self.locale = locale
        self.emailConfirmationGuid = emailConfirmationGuid
        self.gravatarHash = gravatarHash
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.forgotPasswordGuid = forgotPasswordGuid
        self.forgotPasswordDate = forgotPasswordDate
        self.bio = bio
        self.avatarFileName = avatarFileName
        self.reason = reason
        self.isApproved = isApproved
        self.twoFactorEnabled = twoFactorEnabled
        
        self.headerFileName = headerFileName
        self.statusesCount = statusesCount
        self.followersCount = followersCount
        self.followingCount = followingCount

        self.sharedInbox = sharedInbox
        self.userInbox = userInbox
        self.userOutbox = userOutbox

        self.userNameNormalized = userName.uppercased()
        self.accountNormalized = account.uppercased()
        self.emailNormalized = email?.uppercased()
        self.activityPubProfileNormalized = activityPubProfile.uppercased()
        self.queryNormalized = "\(self.name?.uppercased() ?? "") \(self.userNameNormalized) \(self.accountNormalized) \(self.activityPubProfileNormalized)"
    }
}

/// Allows `User` to be encoded to and decoded from HTTP messages.
extension User: Content { }

extension User {
    convenience init(from registerUserDto: RegisterUserDto,
                     withPassword password: String,
                     account: String,
                     activityPubProfile: String,
                     salt: String,
                     emailConfirmationGuid: String,
                     gravatarHash: String,
                     isApproved: Bool,
                     privateKey: String,
                     publicKey: String) {
        self.init(
            isLocal: true,
            userName: registerUserDto.userName,
            account: account,
            activityPubProfile: activityPubProfile,
            email: registerUserDto.email,
            name: registerUserDto.name,
            password: password,
            salt: salt,
            emailWasConfirmed: false,
            isBlocked: false,
            locale: registerUserDto.locale ?? "en_US",
            emailConfirmationGuid: emailConfirmationGuid,
            gravatarHash: gravatarHash,
            privateKey: privateKey,
            publicKey: publicKey,
            manuallyApprovesFollowers: false,
            reason: registerUserDto.reason,
            isApproved: isApproved
        )
    }
    
    convenience init(fromOAuth oauthUser: OAuthUser,
                     account: String,
                     activityPubProfile: String,
                     withPassword password: String,
                     salt: String,
                     gravatarHash: String,
                     isApproved: Bool,
                     privateKey: String,
                     publicKey: String) {
        self.init(
            isLocal: true,
            userName: oauthUser.email,
            account: account,
            activityPubProfile: activityPubProfile,
            email: oauthUser.email,
            name: oauthUser.name,
            password: password,
            salt: salt,
            emailWasConfirmed: true,
            isBlocked: false,
            locale: "en_US",
            emailConfirmationGuid: UUID.init().uuidString,
            gravatarHash: gravatarHash,
            privateKey: privateKey,
            publicKey: publicKey,
            manuallyApprovesFollowers: false,
            isApproved: isApproved
        )
    }

    func getUserName() -> String {
        guard let userName = self.name else {
            return self.userName
        }

        return userName
    }
}
