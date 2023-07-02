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
    var avatarUrl: String?
    var headerUrl: String?
    var headerFileName: String?
    var statusesCount: Int
    var followersCount: Int
    var followingCount: Int
    
    var fields: [FlexiFieldDto]?
}

extension UserDto {
    init(from user: User, flexiFields: [FlexiField], baseStoragePath: String) {
        let avatarUrl = UserDto.getAvatarUrl(user: user, baseStoragePath: baseStoragePath)
        let headerUrl = UserDto.getHeaderUrl(user: user, baseStoragePath: baseStoragePath)

        self.init(
            id: user.stringId(),
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
            fields: flexiFields.map({ FlexiFieldDto(from: $0) })
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
