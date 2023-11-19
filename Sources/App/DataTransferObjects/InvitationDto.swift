//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

public struct InvitationDto {
    var id: String?
    var code: String
    var user: UserDto
    var invited: UserDto?
    var createdAt: Date?
    var updatedAt: Date?
}

extension InvitationDto {
    init(from invitation: Invitation, baseStoragePath: String, baseAddress: String) {
        self.init(id: invitation.stringId(),
                  code: invitation.code,
                  user: UserDto(from: invitation.user, baseStoragePath: baseStoragePath, baseAddress: baseAddress),
                  invited: InvitationDto.getInvitedUserDto(invitedUser: invitation.invited, baseStoragePath: baseStoragePath, baseAddress: baseAddress),
                  createdAt: invitation.createdAt,
                  updatedAt: invitation.updatedAt)
    }
    
    private static func getInvitedUserDto(invitedUser: User?, baseStoragePath: String, baseAddress: String) -> UserDto? {
        guard let invitedUser else {
            return nil
        }
        
        return UserDto(from: invitedUser, flexiFields: [], baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
}

extension InvitationDto: Content { }
