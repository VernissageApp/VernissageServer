//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class User: Model {

    static let schema = "Users"
    
    @ID(custom: .id, generatedBy: .user)
    var id: UInt64?
    
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
    
    @Field(key: "emailConfirmationGuid")
    var emailConfirmationGuid: String?
    
    @Field(key: "forgotPasswordGuid")
    var forgotPasswordGuid: String?
    
    @Field(key: "forgotPasswordDate")
    var forgotPasswordDate: Date?
    
    @Field(key: "bio")
    var bio: String?
    
    @Field(key: "location")
    var location: String?
    
    @Field(key: "website")
    var website: String?
    
    @Field(key: "birthDate")
    var birthDate: Date?

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
    
    @Field(key: "manuallyApprovesFollowers")
    var manuallyApprovesFollowers: Bool
    
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
    
    @Siblings(through: UserRole.self, from: \.$user, to: \.$role)
    var roles: [Role]

    init() { }
    
    init(id: UInt64? = nil,
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
         emailConfirmationGuid: String? = nil,
         gravatarHash: String? = nil,
         privateKey: String? = nil,
         publicKey: String? = nil,
         manuallyApprovesFollowers: Bool = false,
         forgotPasswordGuid: String? = nil,
         forgotPasswordDate: Date? = nil,
         bio: String? = nil,
         location: String? = nil,
         website: String? = nil,
         birthDate: Date? = nil
    ) {
        self.id = id ?? Frostflake.generate()
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
        self.emailConfirmationGuid = emailConfirmationGuid
        self.gravatarHash = gravatarHash
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.forgotPasswordGuid = forgotPasswordGuid
        self.forgotPasswordDate = forgotPasswordDate
        self.bio = bio
        self.location = location
        self.website = website
        self.birthDate = birthDate

        self.userNameNormalized = userName.uppercased()
        self.accountNormalized = account.uppercased()
        self.emailNormalized = email?.uppercased()
        self.activityPubProfileNormalized = activityPubProfile.uppercased()
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
            emailConfirmationGuid: emailConfirmationGuid,
            gravatarHash: gravatarHash,
            privateKey: privateKey,
            publicKey: publicKey,
            manuallyApprovesFollowers: false,
            bio: registerUserDto.bio,
            location: registerUserDto.location,
            website: registerUserDto.website,
            birthDate: registerUserDto.birthDate
        )
    }
    
    convenience init(fromOAuth oauthUser: OAuthUser,
                     account: String,
                     activityPubProfile: String,
                     withPassword password: String,
                     salt: String,
                     gravatarHash: String,
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
            emailConfirmationGuid: UUID.init().uuidString,
            gravatarHash: gravatarHash,
            privateKey: privateKey,
            publicKey: publicKey,
            manuallyApprovesFollowers: false
        )
    }

    func getUserName() -> String {
        guard let userName = self.name else {
            return self.userName
        }

        return userName
    }
}
