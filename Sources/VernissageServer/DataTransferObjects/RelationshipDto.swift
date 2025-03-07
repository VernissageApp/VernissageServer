//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RelationshipDto {
    var userId: String
    
    /// If signed in user is following particural user (`source -> target`).
    var following: Bool
    
    /// If signed in user is followed by particural user (`source <- target`)
    var followedBy: Bool
    
    /// If signed in user requested follow (`source -> (request) -> target`).
    var requested: Bool
    
    /// If signed in user has been requested by particural user (`source <- (request) <- target`).
    var requestedBy: Bool
    
    /// If signed in user muted user's statuses.
    var mutedStatuses: Bool
    
    /// If signed in user muted user's reblogs.
    var mutedReblogs: Bool
    
    /// If signed in user muted user's notifications.
    var mutedNotifications: Bool
}

extension RelationshipDto: Content { }
