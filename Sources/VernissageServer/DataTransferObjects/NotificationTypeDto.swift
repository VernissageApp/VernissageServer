//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum NotificationTypeDto: String {
    /// Someone mentioned you in their status.
    case mention
    
    /// Someone you enabled notifications for has posted a status.
    case status
    
    /// Someone boosted one of your statuses.
    case reblog
    
    /// Someone followed you.
    case follow
    
    /// Someone requested to follow you.
    case followRequest
    
    /// Someone favourited one of your statuses.
    case favourite
    
    /// A status you boosted with has been edited.
    case update
    
    /// Someone signed up (optionally sent to admins).
    case adminSignUp
    
    /// A new report has been filed.
    case adminReport
    
    /// A new comment to status has been added.
    case newComment
}

extension NotificationTypeDto {
    public func translate() -> NotificationType {
        switch self {
        case .mention:
            return NotificationType.mention
        case .status:
            return NotificationType.status
        case .reblog:
            return NotificationType.reblog
        case .follow:
            return NotificationType.follow
        case .followRequest:
            return NotificationType.followRequest
        case .favourite:
            return NotificationType.favourite
        case .update:
            return NotificationType.update
        case .adminSignUp:
            return NotificationType.adminSignUp
        case .adminReport:
            return NotificationType.adminReport
        case .newComment:
            return NotificationType.newComment
        }
    }
    
    public static func from(_ statusVisibility: NotificationType) -> NotificationTypeDto {
        switch statusVisibility {
        case .mention:
            return NotificationTypeDto.mention
        case .status:
            return NotificationTypeDto.status
        case .reblog:
            return NotificationTypeDto.reblog
        case .follow:
            return NotificationTypeDto.follow
        case .followRequest:
            return NotificationTypeDto.followRequest
        case .favourite:
            return NotificationTypeDto.favourite
        case .update:
            return NotificationTypeDto.update
        case .adminSignUp:
            return NotificationTypeDto.adminSignUp
        case .adminReport:
            return NotificationTypeDto.adminReport
        case .newComment:
            return NotificationTypeDto.newComment
        }
    }
}

extension NotificationTypeDto: Content { }
