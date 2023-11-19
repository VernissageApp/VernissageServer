//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserDto: Codable {
    var id: String?
    var isLocal: Bool
    var userName: String
    var account: String
    var email: String?
    var name: String?
    var bio: String?
    var avatarUrl: String?
    var headerUrl: String?
    var statusesCount: Int
    var followersCount: Int
    var followingCount: Int
    var emailWasConfirmed: Bool
    var locale: String?
    var activityPubProfile: String
    var fields: [FlexiFieldDto]?
    var bioHtml: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isLocal
        case userName
        case account
        case email
        case name
        case bio
        case avatarUrl
        case headerUrl
        case statusesCount
        case followersCount
        case followingCount
        case emailWasConfirmed
        case locale
        case fields
        case bioHtml
        case activityPubProfile
        case createdAt
        case updatedAt
    }
    
    init(id: String? = nil,
         isLocal: Bool,
         userName: String,
         account: String,
         email: String? = nil,
         name: String? = nil,
         bio: String? = nil,
         avatarUrl: String? = nil,
         headerUrl: String? = nil,
         statusesCount: Int,
         followersCount: Int,
         followingCount: Int,
         emailWasConfirmed: Bool,
         activityPubProfile: String = "",
         locale: String? = nil,
         fields: [FlexiFieldDto]? = nil,
         createdAt: Date? = nil,
         updatedAt: Date? = nil,
         baseAddress: String) {
        self.id = id
        self.isLocal = isLocal
        self.userName = userName
        self.account = account
        self.email = email
        self.name = name
        self.bio = bio
        self.avatarUrl = avatarUrl
        self.headerUrl = headerUrl
        self.statusesCount = statusesCount
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.emailWasConfirmed = emailWasConfirmed
        self.locale = locale
        self.fields = fields
        self.activityPubProfile = activityPubProfile
        self.bioHtml = self.isLocal ? self.bio?.html(baseAddress: baseAddress) : self.bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        isLocal = try values.decodeIfPresent(Bool.self, forKey: .isLocal) ?? true
        userName = try values.decodeIfPresent(String.self, forKey: .userName) ?? ""
        account = try values.decodeIfPresent(String.self, forKey: .account) ?? ""
        email = try values.decodeIfPresent(String.self, forKey: .email)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        bio = try values.decodeIfPresent(String.self, forKey: .bio)
        avatarUrl = try values.decodeIfPresent(String.self, forKey: .avatarUrl)
        headerUrl = try values.decodeIfPresent(String.self, forKey: .headerUrl)
        statusesCount = try values.decodeIfPresent(Int.self, forKey: .statusesCount) ?? 0
        followersCount = try values.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try values.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        emailWasConfirmed = try values.decodeIfPresent(Bool.self, forKey: .emailWasConfirmed) ?? false
        locale = try values.decodeIfPresent(String.self, forKey: .locale)
        fields = try values.decodeIfPresent([FlexiFieldDto].self, forKey: .fields) ?? []
        activityPubProfile = try values.decodeIfPresent(String.self, forKey: .activityPubProfile) ?? ""
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(isLocal, forKey: .isLocal)
        try container.encodeIfPresent(userName, forKey: .userName)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(headerUrl, forKey: .headerUrl)
        try container.encodeIfPresent(statusesCount, forKey: .statusesCount)
        try container.encodeIfPresent(followersCount, forKey: .followersCount)
        try container.encodeIfPresent(followingCount, forKey: .followingCount)
        try container.encodeIfPresent(emailWasConfirmed, forKey: .emailWasConfirmed)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encodeIfPresent(bioHtml, forKey: .bioHtml)
        try container.encodeIfPresent(activityPubProfile, forKey: .activityPubProfile)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

extension UserDto {
    init(from user: User, flexiFields: [FlexiField], baseStoragePath: String, baseAddress: String) {
        let avatarUrl = UserDto.getAvatarUrl(user: user, baseStoragePath: baseStoragePath)
        let headerUrl = UserDto.getHeaderUrl(user: user, baseStoragePath: baseStoragePath)

        self.init(
            id: user.stringId(),
            isLocal: user.isLocal,
            userName: user.userName,
            account: user.account,
            email: user.email,
            name: user.name,
            bio: user.bio,
            avatarUrl: avatarUrl,
            headerUrl: headerUrl,
            statusesCount: user.statusesCount,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            emailWasConfirmed: user.emailWasConfirmed ?? false,
            activityPubProfile: user.activityPubProfile,
            locale: user.locale,
            fields: flexiFields.map({ FlexiFieldDto(from: $0, baseAddress: baseAddress) }),
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
            baseAddress: baseAddress
        )
    }
    
    private static func getAvatarUrl(user: User, baseStoragePath: String) -> String? {
        guard let avatarFileName = user.avatarFileName else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + avatarFileName
    }
    
    private static func getHeaderUrl(user: User, baseStoragePath: String) -> String? {
        guard let headerFileName = user.headerFileName else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + headerFileName
    }
}

extension UserDto: Content { }

extension UserDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("bio", as: String?.self, is: .count(...500) || .nil, required: false)
    }
}
