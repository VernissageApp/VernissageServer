//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ApplicationSettings {
    // Host settings.
    public let baseAddress: String
    public let domain: String
    
    // General settings.
    public let isRegistrationOpened: Bool
    public let isRegistrationByApprovalOpened: Bool
    public let isRegistrationByInvitationsOpened: Bool
    public let corsOrigin: String?
    
    // Object storage (S3) settings.
    public let s3Address: String?
    public let s3Region: String?
    public let s3Bucket: String?
    public let s3AccessKeyId: String?
    public let s3SecretAccessKey: String?
    
    // Recaptcha.
    public let isRecaptchaEnabled: Bool
    public let recaptchaKey: String
    
    // Events to store.
    public let eventsToStore: [EventType]
    
    init(baseAddress: String = "",
         domain: String = "",
         isRecaptchaEnabled: Bool = false,
         isRegistrationOpened: Bool = false,
         isRegistrationByApprovalOpened: Bool = false,
         isRegistrationByInvitationsOpened: Bool = false,
         recaptchaKey: String = "",
         eventsToStore: String = "",
         corsOrigin: String? = nil,
         s3Address: String? = nil,
         s3Region: String? = nil,
         s3Bucket: String? = nil,
         s3AccessKeyId: String? = nil,
         s3SecretAccessKey: String? = nil
    ) {
        self.baseAddress = baseAddress
        self.domain = domain
        self.isRecaptchaEnabled = isRecaptchaEnabled
        self.isRegistrationOpened = isRegistrationOpened
        self.isRegistrationByApprovalOpened = isRegistrationByApprovalOpened
        self.isRegistrationByInvitationsOpened = isRegistrationByInvitationsOpened
        self.recaptchaKey = recaptchaKey
        self.corsOrigin = corsOrigin
        
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
    }
}
