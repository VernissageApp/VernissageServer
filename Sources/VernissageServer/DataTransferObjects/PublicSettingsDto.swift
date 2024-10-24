//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct PublicSettingsDto {
    var maximumNumberOfInvitations: Int
    var isOpenAIEnabled: Bool
    var webPushVapidPublicKey: String?
    var s3Address: String?

    var patreonUrl: String?
    var mastodonUrl: String?
    let totalCost: Int
    let usersSupport: Int
    
    let showLocalTimelineForAnonymous: Bool
    let showTrendingForAnonymous: Bool
    let showEditorsChoiceForAnonymous: Bool
    let showEditorsUsersChoiceForAnonymous: Bool
    let showHashtagsForAnonymous: Bool
    let showCategoriesForAnonymous: Bool
}

extension PublicSettingsDto: Content { }
