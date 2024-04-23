//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SettingsDto {
    var isRegistrationOpened: Bool
    var isRegistrationByApprovalOpened: Bool
    var isRegistrationByInvitationsOpened: Bool
    
    var isRecaptchaEnabled: Bool
    var recaptchaKey: String
    
    var emailHostname: String
    var emailPort: Int
    var emailUserName: String
    var emailPassword: String
    var emailSecureMethod: EmailSecureMethodDto
    var emailFromAddress: String
    var emailFromName: String
    
    var webTitle: String
    var webDescription: String
    var webEmail: String
    var webThumbnail: String
    var webLanguages: String
    var webContactUserId: String
    
    var maxCharacters: Int
    var maxMediaAttachments: Int
    var imageSizeLimit: Int
    var maximumNumberOfInvitations: Int
    var corsOrigin: String
    var eventsToStore: [EventType]
    var systemDefaultUserId: String
    
    var isOpenAIEnabled: Bool
    var openAIKey: String
    
    init(basedOn settings: [Setting]) {
        self.isRegistrationOpened = settings.getBool(.isRegistrationOpened) ?? false
        self.isRegistrationByApprovalOpened = settings.getBool(.isRegistrationByApprovalOpened) ?? false
        self.isRegistrationByInvitationsOpened = settings.getBool(.isRegistrationByInvitationsOpened) ?? false
        
        self.isRecaptchaEnabled = settings.getBool(.isRecaptchaEnabled) ?? false
        self.recaptchaKey = settings.getString(.recaptchaKey) ?? ""
        
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
        self.webEmail = settings.getString(.webEmail) ?? ""
        self.webThumbnail = settings.getString(.webThumbnail) ?? ""
        self.webLanguages = settings.getString(.webLanguages) ?? ""
        self.webContactUserId = settings.getString(.webContactUserId) ?? ""
        self.systemDefaultUserId = settings.getString(.systemDefaultUserId) ?? ""
        
        self.isOpenAIEnabled = settings.getBool(.isOpenAIEnabled) ?? false
        self.openAIKey = settings.getString(.openAIKey) ?? ""
    }
}

extension SettingsDto: Content { }
