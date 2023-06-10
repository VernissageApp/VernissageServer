//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct UserDto {
    var id: String?
    var userName: String
    var account: String
    var email: String?
    var name: String?
    var bio: String?
    var location: String?
    var website: String?
    var birthDate: Date?
    var gravatarHash: String?
    var avatarUrl: String?
}

extension UserDto {
    init(from user: User, baseStoragePath: String) {
        let avatarUrl = UserDto.getAvatarUrl(user: user, baseStoragePath: baseStoragePath)

        self.init(
            id: user.stringId(),
            userName: user.userName,
            account: user.account,
            email: user.email,
            name: user.name,
            bio: user.bio,
            location: user.location,
            website: user.website,
            birthDate: user.birthDate,
            gravatarHash: user.gravatarHash,
            avatarUrl: avatarUrl
        )
    }
    
    private static func getAvatarUrl(user: User, baseStoragePath: String) -> String? {
        guard let avatarFileName = user.avatarFileName else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + avatarFileName
    }
}

extension UserDto: Content { }

extension UserDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("location", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("website", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("bio", as: String?.self, is: .count(...500) || .nil, required: false)
    }
}
