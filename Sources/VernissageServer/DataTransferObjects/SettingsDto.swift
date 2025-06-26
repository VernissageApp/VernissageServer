//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SettingsDto {
    var isRegistrationOpened: Bool
    var isRegistrationByApprovalOpened: Bool
    var isRegistrationByInvitationsOpened: Bool
    
    var isQuickCaptchaEnabled: Bool
    
    var emailHostname: String
    var emailPort: Int
    var emailUserName: String
    var emailPassword: String
    var emailSecureMethod: EmailSecureMethodDto
    var emailFromAddress: String
    var emailFromName: String
    
    var webTitle: String
    var webDescription: String
    var webLongDescription: String
    var webEmail: String
    var webThumbnail: String
    var webLanguages: String
    var webContactUserId: String
    var patreonUrl: String
    var mastodonUrl: String
    var statusPurgeAfterDays: Int
    var imagesUrl: String
    var showNews: Bool
    var showNewsForAnonymous: Bool
    var showSharedBusinessCards: Bool
    var imageQuality: Int
    
    var maxCharacters: Int
    var maxMediaAttachments: Int
    var imageSizeLimit: Int
    var maximumNumberOfInvitations: Int
    var corsOrigin: String
    var eventsToStore: [EventType]
    var systemDefaultUserId: String
    
    var isOpenAIEnabled: Bool
    var openAIKey: String
    var openAIModel: String
    
    var isWebPushEnabled: Bool
    var webPushEndpoint: String
    var webPushSecretKey: String
    var webPushVapidPublicKey: String
    var webPushVapidPrivateKey: String
    var webPushVapidSubject: String
    
    var totalCost: Int
    var usersSupport: Int
    
    var showLocalTimelineForAnonymous: Bool
    var showTrendingForAnonymous: Bool
    var showEditorsChoiceForAnonymous: Bool
    var showEditorsUsersChoiceForAnonymous: Bool
    var showHashtagsForAnonymous: Bool
    var showCategoriesForAnonymous: Bool
    
    // Privacy and Terms of Service.
    var privacyPolicyUpdatedAt: String
    var privacyPolicyContent: String
    var termsOfServiceUpdatedAt: String
    var termsOfServiceContent: String
    
    // Custom style and script.
    var customInlineScript: String
    var customInlineStyle: String
    var customFileScript: String
    var customFileStyle: String
    
    init(basedOn settings: [Setting]) {
        self.isRegistrationOpened = settings.getBool(.isRegistrationOpened) ?? false
        self.isRegistrationByApprovalOpened = settings.getBool(.isRegistrationByApprovalOpened) ?? false
        self.isRegistrationByInvitationsOpened = settings.getBool(.isRegistrationByInvitationsOpened) ?? false
        
        self.isQuickCaptchaEnabled = settings.getBool(.isQuickCaptchaEnabled) ?? false
        
        self.corsOrigin = settings.getString(.corsOrigin) ?? ""
        self.maximumNumberOfInvitations = settings.getInt(.maximumNumberOfInvitations) ?? 0
        self.maxCharacters = settings.getInt(.maxCharacters) ?? 0
        self.maxMediaAttachments = settings.getInt(.maxMediaAttachments) ?? 0
        self.imageSizeLimit = settings.getInt(.imageSizeLimit) ?? 0
        
        self.emailHostname = settings.getString(.emailHostname) ?? ""
        self.emailPort = settings.getInt(.emailPort) ?? 0
        self.emailUserName = settings.getString(.emailUserName) ?? ""
        self.emailPassword = settings.getString(.emailPassword) ?? ""
        self.emailSecureMethod = EmailSecureMethodDto(rawValue: settings.getString(.emailSecureMethod) ?? "none") ?? .none
        self.emailFromAddress = settings.getString(.emailFromAddress) ?? ""
        self.emailFromName = settings.getString(.emailFromName) ?? ""
        
        self.eventsToStore = settings.getString(.eventsToStore)?.split(separator: ",").map({ EventType(rawValue: String($0)) ?? .unknown }) ?? []

        self.webTitle = settings.getString(.webTitle) ?? ""
        self.webDescription = settings.getString(.webDescription) ?? ""
        self.webLongDescription = settings.getString(.webLongDescription) ?? ""
        self.webEmail = settings.getString(.webEmail) ?? ""
        self.webThumbnail = settings.getString(.webThumbnail) ?? ""
        self.webLanguages = settings.getString(.webLanguages) ?? ""
        self.webContactUserId = settings.getString(.webContactUserId) ?? ""
        self.systemDefaultUserId = settings.getString(.systemDefaultUserId) ?? ""
        self.patreonUrl = settings.getString(.patreonUrl) ?? ""
        self.mastodonUrl = settings.getString(.mastodonUrl) ?? ""
        self.statusPurgeAfterDays = settings.getInt(.statusPurgeAfterDays) ?? 180
        self.imagesUrl = settings.getString(.imagesUrl) ?? ""
        self.showNews = settings.getBool(.showNews) ?? false
        self.showNewsForAnonymous = settings.getBool(.showNewsForAnonymous) ?? false
        self.showSharedBusinessCards = settings.getBool(.showSharedBusinessCards) ?? false
        self.imageQuality = settings.getInt(.imageQuality) ?? Constants.imageQuality
        
        self.isOpenAIEnabled = settings.getBool(.isOpenAIEnabled) ?? false
        self.openAIKey = settings.getString(.openAIKey) ?? ""
        self.openAIModel = settings.getString(.openAIModel) ?? ""
        
        self.isWebPushEnabled = settings.getBool(.isWebPushEnabled) ?? false
        self.webPushEndpoint = settings.getString(.webPushEndpoint) ?? ""
        self.webPushSecretKey = settings.getString(.webPushSecretKey) ?? ""
        self.webPushVapidPublicKey = settings.getString(.webPushVapidPublicKey) ?? ""
        self.webPushVapidPrivateKey = settings.getString(.webPushVapidPrivateKey) ?? ""
        self.webPushVapidSubject = settings.getString(.webPushVapidSubject) ?? ""
        
        self.totalCost = settings.getInt(.totalCost) ?? 0
        self.usersSupport = settings.getInt(.usersSupport) ?? 0
        
        self.showLocalTimelineForAnonymous = settings.getBool(.showLocalTimelineForAnonymous) ?? false
        self.showTrendingForAnonymous = settings.getBool(.showTrendingForAnonymous) ?? false
        self.showEditorsChoiceForAnonymous = settings.getBool(.showEditorsChoiceForAnonymous) ?? false
        self.showEditorsUsersChoiceForAnonymous = settings.getBool(.showEditorsUsersChoiceForAnonymous) ?? false
        self.showHashtagsForAnonymous = settings.getBool(.showHashtagsForAnonymous) ?? false
        self.showCategoriesForAnonymous = settings.getBool(.showCategoriesForAnonymous) ?? false
        
        self.privacyPolicyUpdatedAt = settings.getString(.privacyPolicyUpdatedAt) ?? ""
        self.privacyPolicyContent = settings.getString(.privacyPolicyContent) ?? ""
        self.termsOfServiceUpdatedAt = settings.getString(.termsOfServiceUpdatedAt) ?? ""
        self.termsOfServiceContent = settings.getString(.termsOfServiceContent) ?? ""
        
        self.customInlineScript = settings.getString(.customInlineScript) ?? ""
        self.customInlineStyle = settings.getString(.customInlineStyle) ?? ""
        self.customFileScript = settings.getString(.customFileScript) ?? ""
        self.customFileStyle = settings.getString(.customFileStyle) ?? ""
    }
}

extension SettingsDto: Content { }
