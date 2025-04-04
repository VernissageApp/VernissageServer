//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct InvitationDto {
    var id: String?
    var code: String
    var user: UserDto
    var invited: UserDto?
    var createdAt: Date?
    var updatedAt: Date?
}

extension InvitationDto {
    init(from invitation: Invitation, baseImagesPath: String, baseAddress: String) {
        self.init(id: invitation.stringId(),
                  code: invitation.code,
                  user: UserDto(from: invitation.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  invited: InvitationDto.getInvitedUserDto(invitedUser: invitation.invited, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  createdAt: invitation.createdAt,
                  updatedAt: invitation.updatedAt)
    }
    
    private static func getInvitedUserDto(invitedUser: User?, baseImagesPath: String, baseAddress: String) -> UserDto? {
        guard let invitedUser else {
            return nil
        }
        
        return UserDto(from: invitedUser, flexiFields: [], baseImagesPath: baseImagesPath, baseAddress: baseAddress)
    }
}

extension InvitationDto: Content { }
