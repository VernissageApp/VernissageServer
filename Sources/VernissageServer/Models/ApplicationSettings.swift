//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

/// Entity that holds all system settings.
struct ApplicationSettings {
    // Host settings.
    let baseAddress: String
    let domain: String
    
    // General settings.
    let webTitle: String
    let webDescription: String
    let webLongDescription: String
    let webEmail: String
    let webThumbnail: String
    let webLanguages: String
    let webContactUserId: String
    let isRegistrationOpened: Bool
    let isRegistrationByApprovalOpened: Bool
    let isRegistrationByInvitationsOpened: Bool
    let corsOrigin: String?
    let maximumNumberOfInvitations: Int
    let maxCharacters: Int
    let maxMediaAttachments: Int
    let imageSizeLimit: Int
    let statusPurgeAfterDays: Int
    let showNews: Bool
    let showNewsForAnonymous: Bool
    let showSharedBusinessCards: Bool
    let imageQuality: Int
    
    // Email settings.
    let emailFromAddress: String
    let emailFromName: String
    
    // Object storage (S3) settings.
    let s3Address: String?
    let s3Region: String?
    let s3Bucket: String?
    let s3AccessKeyId: String?
    let s3SecretAccessKey: String?
    
    // Image Url (S3 storage, Cloud front, or other CDN).
    let imagesUrl: String?
    
    // Quick captcha.
    let isQuickCaptchaEnabled: Bool

    // OpenAI.
    let isOpenAIEnabled: Bool
    let openAIKey: String
    let openAIModel: String
    
    // WebPush.
    let isWebPushEnabled: Bool
    let webPushEndpoint: String
    let webPushSecretKey: String
    let webPushVapidPublicKey: String
    let webPushVapidPrivateKey: String
    let webPushVapidSubject: String

    // Visible pages for anonymous.
    let showLocalTimelineForAnonymous: Bool
    let showTrendingForAnonymous: Bool
    let showEditorsChoiceForAnonymous: Bool
    let showEditorsUsersChoiceForAnonymous: Bool
    let showHashtagsForAnonymous: Bool
    let showCategoriesForAnonymous: Bool
    
    // Events to store.
    let eventsToStore: [EventType]
    
    init(basedOn settingsFromDb: [Setting],
         baseAddress: String = "",
         domain: String = "",
         s3Address: String? = nil,
         s3Region: String? = nil,
         s3Bucket: String? = nil,
         s3AccessKeyId: String? = nil,
         s3SecretAccessKey: String? = nil
    ) {
        self.baseAddress = baseAddress
        self.domain = domain
        
        if (s3Address ?? "").isEmpty == false {
            self.s3Address = s3Address
        } else {
            self.s3Address = nil
        }

        if (s3Region ?? "").isEmpty == false {
            self.s3Region = s3Region
        } else {
            self.s3Region = nil
        }
        
        if (s3Bucket ?? "").isEmpty == false {
            self.s3Bucket = s3Bucket
        } else {
            self.s3Bucket = nil
        }
        
        if (s3AccessKeyId ?? "").isEmpty == false {
            self.s3AccessKeyId = s3AccessKeyId
        } else {
            self.s3AccessKeyId = nil
        }
        
        if (s3SecretAccessKey ?? "").isEmpty == false {
            self.s3SecretAccessKey = s3SecretAccessKey
        } else {
            self.s3SecretAccessKey = nil
        }
        
        // Recalculate events to store in the database.
        let eventsToStore = settingsFromDb.getString(.eventsToStore) ?? ""
        var eventsArray: [EventType] = []
        EventType.allCases.forEach {
            if eventsToStore.contains($0.rawValue) {
                eventsArray.append($0)
            }
        }
        
        self.eventsToStore = eventsArray
        
        // Other settings often used in the system from database.
        self.webTitle = settingsFromDb.getString(.webTitle) ?? ""
        self.webDescription = settingsFromDb.getString(.webDescription) ?? ""
        self.corsOrigin = settingsFromDb.getString(.corsOrigin) ?? ""
        self.webLongDescription = settingsFromDb.getString(.webLongDescription) ?? ""
        self.webEmail = settingsFromDb.getString(.webEmail) ?? ""
        self.webThumbnail = settingsFromDb.getString(.webThumbnail) ?? ""
        self.webLanguages = settingsFromDb.getString(.webLanguages) ?? ""
        self.webContactUserId = settingsFromDb.getString(.webContactUserId) ?? ""
        self.isQuickCaptchaEnabled = settingsFromDb.getBool(.isQuickCaptchaEnabled) ?? false
        self.isRegistrationOpened = settingsFromDb.getBool(.isRegistrationOpened) ?? false
        self.isRegistrationByApprovalOpened = settingsFromDb.getBool(.isRegistrationByApprovalOpened) ?? false
        self.isRegistrationByInvitationsOpened = settingsFromDb.getBool(.isRegistrationByInvitationsOpened) ?? false
        self.emailFromAddress = settingsFromDb.getString(.emailFromAddress) ?? ""
        self.emailFromName = settingsFromDb.getString(.emailFromName) ?? ""
        self.imagesUrl = settingsFromDb.getString(.imagesUrl) ?? ""
        self.maximumNumberOfInvitations = settingsFromDb.getInt(.maximumNumberOfInvitations) ?? 0
        self.maxCharacters = settingsFromDb.getInt(.maxCharacters) ?? Constants.statusMaxCharacters
        self.maxMediaAttachments = settingsFromDb.getInt(.maxMediaAttachments) ?? Constants.statusMaxMediaAttachments
        self.imageSizeLimit = settingsFromDb.getInt(.imageSizeLimit) ?? Constants.imageSizeLimit
        self.statusPurgeAfterDays = settingsFromDb.getInt(.statusPurgeAfterDays) ?? 180
        self.isOpenAIEnabled = settingsFromDb.getBool(.isOpenAIEnabled) ?? false
        self.openAIKey = settingsFromDb.getString(.openAIKey) ?? ""
        self.openAIModel = settingsFromDb.getString(.openAIModel) ?? ""
        self.isWebPushEnabled = settingsFromDb.getBool(.isWebPushEnabled) ?? false
        self.webPushEndpoint = settingsFromDb.getString(.webPushEndpoint) ?? ""
        self.webPushSecretKey = settingsFromDb.getString(.webPushSecretKey) ?? ""
        self.webPushVapidPublicKey = settingsFromDb.getString(.webPushVapidPublicKey) ?? ""
        self.webPushVapidPrivateKey = settingsFromDb.getString(.webPushVapidPrivateKey) ?? ""
        self.webPushVapidSubject = settingsFromDb.getString(.webPushVapidSubject) ?? ""
        self.showLocalTimelineForAnonymous = settingsFromDb.getBool(.showLocalTimelineForAnonymous) ?? false
        self.showTrendingForAnonymous = settingsFromDb.getBool(.showTrendingForAnonymous) ?? false
        self.showEditorsChoiceForAnonymous = settingsFromDb.getBool(.showEditorsChoiceForAnonymous) ?? false
        self.showEditorsUsersChoiceForAnonymous = settingsFromDb.getBool(.showEditorsUsersChoiceForAnonymous) ?? false
        self.showHashtagsForAnonymous = settingsFromDb.getBool(.showHashtagsForAnonymous) ?? false
        self.showCategoriesForAnonymous = settingsFromDb.getBool(.showCategoriesForAnonymous) ?? false
        self.showNews = settingsFromDb.getBool(.showNews) ?? false
        self.showNewsForAnonymous = settingsFromDb.getBool(.showNewsForAnonymous) ?? false
        self.showSharedBusinessCards = settingsFromDb.getBool(.showSharedBusinessCards) ?? false
        self.imageQuality = settingsFromDb.getInt(.imageQuality) ?? Constants.imageQuality
    }
}
