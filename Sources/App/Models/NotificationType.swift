//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum NotificationType: Int, Codable {
    /// Someone mentioned you in their status.
    case mention = 1
    
    /// Someone you enabled notifications for has posted a status.
    case status = 2
    
    /// Someone boosted one of your statuses.
    case reblog = 3
    
    /// Someone followed you.
    case follow = 4
    
    /// Someone requested to follow you.
    case followRequest = 5
    
    /// Someone favourited one of your statuses.
    case favourite = 6
    
    /// A status you boosted with has been edited.
    case update = 7
    
    /// Someone signed up (optionally sent to admins).
    case adminSignUp = 8
    
    /// A new report has been filed.
    case adminReport = 9
}
