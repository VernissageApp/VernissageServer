//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
    
    // Email settings.
    let emailFromAddress: String
    let emailFromName: String
    
    // Object storage (S3) settings.
    let s3Address: String?
    let s3Region: String?
    let s3Bucket: String?
    let s3AccessKeyId: String?
    let s3SecretAccessKey: String?
    
    // Recaptcha.
    let isRecaptchaEnabled: Bool
    let recaptchaKey: String

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

    
    // Events to store.
    let eventsToStore: [EventType]
    
    init(baseAddress: String = "",
         domain: String = "",
         webTitle: String = "",
         webDescription: String = "",
         webEmail: String = "",
         webThumbnail: String = "",
         webLanguages: String = "",
         webContactUserId: String = "",
         isRecaptchaEnabled: Bool = false,
         isRegistrationOpened: Bool = false,
         isRegistrationByApprovalOpened: Bool = false,
         isRegistrationByInvitationsOpened: Bool = false,
         emailFromAddress: String = "",
         emailFromName: String = "",
         recaptchaKey: String = "",
         eventsToStore: String = "",
         corsOrigin: String? = nil,
         s3Address: String? = nil,
         s3Region: String? = nil,
         s3Bucket: String? = nil,
         s3AccessKeyId: String? = nil,
         s3SecretAccessKey: String? = nil,
         maximumNumberOfInvitations: Int = 0,
         maxCharacters: Int = 500,
         maxMediaAttachments: Int = 4,
         imageSizeLimit: Int = 10_485_760,
         isOpenAIEnabled: Bool = false,
         openAIKey: String = "",
         openAIModel: String = "",
         isWebPushEnabled: Bool = false,
         webPushEndpoint: String = "",
         webPushSecretKey: String = "",
         webPushVapidPublicKey: String = "",
         webPushVapidPrivateKey: String = "",
         webPushVapidSubject: String = ""
    ) {
        self.baseAddress = baseAddress
        self.domain = domain
        
        self.webTitle = webTitle
        self.webDescription = webDescription
        self.webEmail = webEmail
        self.webThumbnail = webThumbnail
        self.webLanguages = webLanguages
        self.webContactUserId = webContactUserId
        self.isRecaptchaEnabled = isRecaptchaEnabled
        self.isRegistrationOpened = isRegistrationOpened
        self.isRegistrationByApprovalOpened = isRegistrationByApprovalOpened
        self.isRegistrationByInvitationsOpened = isRegistrationByInvitationsOpened
        self.recaptchaKey = recaptchaKey
        self.corsOrigin = corsOrigin
        self.maximumNumberOfInvitations = maximumNumberOfInvitations
        self.maxCharacters = maxCharacters
        self.maxMediaAttachments = maxMediaAttachments
        self.imageSizeLimit = imageSizeLimit
        
        self.emailFromAddress = emailFromAddress
        self.emailFromName = emailFromName
        
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
        
        var eventsArray: [EventType] = []
        EventType.allCases.forEach {
            if eventsToStore.contains($0.rawValue) {
                eventsArray.append($0)
            }
        }
        
        self.eventsToStore = eventsArray
        self.isOpenAIEnabled = isOpenAIEnabled
        self.openAIKey = openAIKey
        self.openAIModel = openAIModel
        
        self.isWebPushEnabled = isWebPushEnabled
        self.webPushEndpoint = webPushEndpoint
        self.webPushSecretKey = webPushSecretKey
        self.webPushVapidPublicKey = webPushVapidPublicKey
        self.webPushVapidPrivateKey = webPushVapidPrivateKey
        self.webPushVapidSubject = webPushVapidSubject
    }
}
