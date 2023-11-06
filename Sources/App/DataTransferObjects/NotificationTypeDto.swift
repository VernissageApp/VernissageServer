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
}

extension NotificationTypeDto {
    public func translate() -> NotificationType {
        switch self {
        case .mention:
            NotificationType.mention
        case .status:
            NotificationType.status
        case .reblog:
            NotificationType.reblog
        case .follow:
            NotificationType.follow
        case .followRequest:
            NotificationType.followRequest
        case .favourite:
            NotificationType.favourite
        case .update:
            NotificationType.update
        case .adminSignUp:
            NotificationType.adminSignUp
        case .adminReport:
            NotificationType.adminReport
        }
    }
    
    public static func from(_ statusVisibility: NotificationType) -> NotificationTypeDto {
        switch statusVisibility {
        case .mention:
            NotificationTypeDto.mention
        case .status:
            NotificationTypeDto.status
        case .reblog:
            NotificationTypeDto.reblog
        case .follow:
            NotificationTypeDto.follow
        case .followRequest:
            NotificationTypeDto.followRequest
        case .favourite:
            NotificationTypeDto.favourite
        case .update:
            NotificationTypeDto.update
        case .adminSignUp:
            NotificationTypeDto.adminSignUp
        case .adminReport:
            NotificationTypeDto.adminReport
        }
    }
}

extension NotificationTypeDto: Content { }
