//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// System setting.
final class Setting: Model, @unchecked Sendable {
    static let schema = "Settings"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "value")
    var value: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     key: String,
                     value: String
    ) {
        self.init()

        self.id = id
        self.key = key
        self.value = value
    }
}

/// Allows `Setting` to be encoded to and decoded from HTTP messages.
extension Setting: Content { }

public enum SettingKey: String {
    // General.
    case webTitle
    case webDescription
    case webLongDescription
    case webEmail
    case webThumbnail
    case webLanguages
    case webContactUserId
    case isRegistrationOpened
    case isRegistrationByApprovalOpened
    case isRegistrationByInvitationsOpened
    case corsOrigin
    case maximumNumberOfInvitations
    case maxCharacters
    case maxMediaAttachments
    case imageSizeLimit
    case systemDefaultUserId
    case patreonUrl
    case mastodonUrl
    case statusPurgeAfterDays
    case imagesUrl
    case showNews
    case showNewsForAnonymous
    case showSharedBusinessCards
    case imageQuality
    
    // Recaptcha (deprecated: will be deleted).
    case isRecaptchaEnabled
    case recaptchaKey
    
    // Quick captcha.
    case isQuickCaptchaEnabled
    
    // Events to store.
    case eventsToStore
    
    // JWT keys for tokens.
    case jwtPrivateKey
    case jwtPublicKey
    
    // Email server.
    case emailHostname
    case emailPort
    case emailUserName
    case emailPassword
    case emailSecureMethod
    case emailFromAddress
    case emailFromName
    
    // OpenAI.
    case isOpenAIEnabled
    case openAIKey
    case openAIModel
    
    // WebPush.
    case isWebPushEnabled
    case webPushEndpoint
    case webPushSecretKey
    case webPushVapidPublicKey
    case webPushVapidPrivateKey
    case webPushVapidSubject
    
    // Finansial support.
    case totalCost
    case usersSupport
    
    // Visible pages for anonymous.
    case showLocalTimelineForAnonymous
    case showTrendingForAnonymous
    case showEditorsChoiceForAnonymous
    case showEditorsUsersChoiceForAnonymous
    case showHashtagsForAnonymous
    case showCategoriesForAnonymous
    
    // Privacy and Terms of Service.
    case privacyPolicyUpdatedAt
    case privacyPolicyContent
    case termsOfServiceUpdatedAt
    case termsOfServiceContent
    
    // Custom style and script.
    case customInlineScript
    case customInlineStyle
    case customFileScript
    case customFileStyle
}

public enum SettingValue {
    case boolean(Bool)
    case string(String)
    case int(Int)
    
    func value() -> String {
        switch self {
        case .boolean(let bool):
            return bool ? "1" : "0"
        case .string(let string):
            return string
        case .int(let integer):
            return "\(integer)"
        }
    }
}

extension Array where Element == Setting {
    func getSetting(_ key: SettingKey) -> Setting? {
        for item in self where item.key == key.rawValue {
            return item
        }
        
        return nil
    }
    
    func getInt(_ key: SettingKey) -> Int? {
        guard let setting = self.getSetting(key) else {
            return nil
        }

        return Int(setting.value)
    }

    func getString(_ key: SettingKey) -> String? {
        return self.getSetting(key)?.value
    }

    func getBool(_ key: SettingKey) -> Bool? {
        guard let setting = self.getSetting(key) else {
            return nil
        }

        return Int(setting.value) ?? 0 == 1
    }
}
