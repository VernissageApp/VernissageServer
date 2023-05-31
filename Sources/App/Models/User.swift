import Fluent
import Vapor

final class User: Model {

    static let schema = "Users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "userName")
    var userName: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "name")
    var name: String?
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "salt")
    var salt: String
    
    @Field(key: "emailWasConfirmed")
    var emailWasConfirmed: Bool
    
    @Field(key: "isBlocked")
    var isBlocked: Bool
    
    @Field(key: "emailConfirmationGuid")
    var emailConfirmationGuid: String
    
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
    
    @Field(key: "emailNormalized")
    var emailNormalized: String
    
    @Field(key: "gravatarHash")
    var gravatarHash: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deletedAt", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$user)
    var refreshTokens: [RefreshToken]
    
    @Siblings(through: UserRole.self, from: \.$user, to: \.$role)
    var roles: [Role]

    init() { }
    
    init(id: UUID? = nil,
         userName: String,
         email: String,
         name: String?,
         password: String,
         salt: String,
         emailWasConfirmed: Bool,
         isBlocked: Bool,
         emailConfirmationGuid: String,
         gravatarHash: String,
         forgotPasswordGuid: String? = nil,
         forgotPasswordDate: Date? = nil,
         bio: String? = nil,
         location: String? = nil,
         website: String? = nil,
         birthDate: Date? = nil
    ) {
        self.id = id
        self.userName = userName
        self.email = email
        self.name = name
        self.password = password
        self.salt = salt
        self.emailWasConfirmed = emailWasConfirmed
        self.isBlocked = isBlocked
        self.emailConfirmationGuid = emailConfirmationGuid
        self.gravatarHash = gravatarHash
        self.forgotPasswordGuid = forgotPasswordGuid
        self.forgotPasswordDate = forgotPasswordDate
        self.bio = bio
        self.location = location
        self.website = website
        self.birthDate = birthDate

        self.userNameNormalized = userName.uppercased()
        self.emailNormalized = email.uppercased()
    }
}

/// Allows `User` to be encoded to and decoded from HTTP messages.
extension User: Content { }

extension User {
    convenience init(from registerUserDto: RegisterUserDto,
                     withPassword password: String,
                     salt: String,
                     emailConfirmationGuid: String,
                     gravatarHash: String) {
        self.init(
            userName: registerUserDto.userName,
            email: registerUserDto.email,
            name: registerUserDto.name,
            password: password,
            salt: salt,
            emailWasConfirmed: false,
            isBlocked: false,
            emailConfirmationGuid: emailConfirmationGuid,
            gravatarHash: gravatarHash,
            bio: registerUserDto.bio,
            location: registerUserDto.location,
            website: registerUserDto.website,
            birthDate: registerUserDto.birthDate
        )
    }
    
    convenience init(fromOAuth oauthUser: OAuthUser,
                     withPassword password: String,
                     salt: String,
                     gravatarHash: String) {
        self.init(
            userName: oauthUser.email,
            email: oauthUser.email,
            name: oauthUser.name,
            password: password,
            salt: salt,
            emailWasConfirmed: true,
            isBlocked: false,
            emailConfirmationGuid: UUID.init().uuidString,
            gravatarHash: gravatarHash
        )
    }

    func getUserName() -> String {
        guard let userName = self.name else {
            return self.userName
        }

        return userName
    }
}
