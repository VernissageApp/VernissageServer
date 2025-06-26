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
    var imagesUrl: String?
    var showNews: Bool
    var showNewsForAnonymous: Bool
    var showSharedBusinessCards: Bool
    var isQuickCaptchaEnabled: Bool

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
    
    // Privacy and Terms of Service.
    let privacyPolicyUpdatedAt: String
    let privacyPolicyContent: String
    let termsOfServiceUpdatedAt: String
    let termsOfServiceContent: String
    
    // Custom style and script.
    let customInlineScript: String
    let customInlineStyle: String
    let customFileScript: String
    let customFileStyle: String
}

extension PublicSettingsDto: Content { }
