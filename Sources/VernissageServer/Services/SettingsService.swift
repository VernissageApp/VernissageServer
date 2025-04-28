//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import JWTKit

extension Application.Services {
    struct SettingsServiceKey: StorageKey {
        typealias Value = SettingsServiceType
    }

    var settingsService: SettingsServiceType {
        get {
            self.application.storage[SettingsServiceKey.self] ?? SettingsService()
        }
        nonmutating set {
            self.application.storage[SettingsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol SettingsServiceType: Sendable {
    func get(on database: Database) async throws -> [Setting]
    func get(_ key: SettingKey, on database: Database) async throws -> Setting?
    func getApplicationSettings(basedOn settingsFromDb: [Setting], application: Application) throws -> ApplicationSettings
}

/// A service for managing system settings.
final class SettingsService: SettingsServiceType {

    func get(on database: Database) async throws -> [Setting] {
        return try await Setting.query(on: database).all()
    }
    
    func get(_ key: SettingKey, on database: Database) async throws -> Setting? {
        return try await Setting.query(on: database).filter(\.$key == key.rawValue).first()
    }
    
    func getApplicationSettings(basedOn settingsFromDb: [Setting], application: Application) throws -> ApplicationSettings {
        guard let privateKey = settingsFromDb.getString(.jwtPrivateKey)?.data(using: .ascii) else {
            throw Abort(.internalServerError, reason: "Private key is not configured in database.")
        }
        
        let rsaKey: RSAKey = try .private(pem: privateKey)
        application.jwt.signers.use(.rs512(key: rsaKey))
        
        let baseAddress = application.settings.getString(for: "vernissage.baseAddress", withDefault: "http://localhost")
        let baseAddressUrl = URL(string: baseAddress)
                
        let s3Address = application.settings.getString(for: "vernissage.s3Address")
        let s3Region = application.settings.getString(for: "vernissage.s3Region")
        let s3Bucket = application.settings.getString(for: "vernissage.s3Bucket")
        let s3AccessKeyId = application.settings.getString(for: "vernissage.s3AccessKeyId")
        let s3SecretAccessKey = application.settings.getString(for: "vernissage.s3SecretAccessKey")
        
        let applicationSettings = ApplicationSettings(
            baseAddress: baseAddress,
            domain: baseAddressUrl?.host ?? "localhost",
            webTitle: settingsFromDb.getString(.webTitle) ?? "",
            webDescription: settingsFromDb.getString(.webDescription) ?? "",
            webLongDescription: settingsFromDb.getString(.webLongDescription) ?? "",
            webEmail: settingsFromDb.getString(.webEmail) ?? "",
            webThumbnail: settingsFromDb.getString(.webThumbnail) ?? "",
            webLanguages: settingsFromDb.getString(.webLanguages) ?? "",
            webContactUserId: settingsFromDb.getString(.webContactUserId) ?? "",
            isRecaptchaEnabled: settingsFromDb.getBool(.isRecaptchaEnabled) ?? false,
            isRegistrationOpened: settingsFromDb.getBool(.isRegistrationOpened) ?? false,
            isRegistrationByApprovalOpened: settingsFromDb.getBool(.isRegistrationByApprovalOpened) ?? false,
            isRegistrationByInvitationsOpened: settingsFromDb.getBool(.isRegistrationByInvitationsOpened) ?? false,
            emailFromAddress: settingsFromDb.getString(.emailFromAddress) ?? "",
            emailFromName: settingsFromDb.getString(.emailFromName) ?? "",
            recaptchaKey: settingsFromDb.getString(.recaptchaKey) ?? "",
            eventsToStore: settingsFromDb.getString(.eventsToStore) ?? "",
            s3Address: s3Address,
            s3Region: s3Region,
            s3Bucket: s3Bucket,
            s3AccessKeyId: s3AccessKeyId,
            s3SecretAccessKey: s3SecretAccessKey,
            imagesUrl: settingsFromDb.getString(.imagesUrl) ?? "",
            maximumNumberOfInvitations: settingsFromDb.getInt(.maximumNumberOfInvitations) ?? 0,
            maxCharacters: settingsFromDb.getInt(.maxCharacters) ?? 500,
            maxMediaAttachments: settingsFromDb.getInt(.maxMediaAttachments) ?? 4,
            imageSizeLimit: settingsFromDb.getInt(.imageSizeLimit) ?? 10_485_760,
            statusPurgeAfterDays: settingsFromDb.getInt(.statusPurgeAfterDays) ?? 180,
            isOpenAIEnabled: settingsFromDb.getBool(.isOpenAIEnabled) ?? false,
            openAIKey: settingsFromDb.getString(.openAIKey) ?? "",
            openAIModel: settingsFromDb.getString(.openAIModel) ?? "",
            isWebPushEnabled: settingsFromDb.getBool(.isWebPushEnabled) ?? false,
            webPushEndpoint: settingsFromDb.getString(.webPushEndpoint) ?? "",
            webPushSecretKey: settingsFromDb.getString(.webPushSecretKey) ?? "",
            webPushVapidPublicKey: settingsFromDb.getString(.webPushVapidPublicKey) ?? "",
            webPushVapidPrivateKey: settingsFromDb.getString(.webPushVapidPrivateKey) ?? "",
            webPushVapidSubject: settingsFromDb.getString(.webPushVapidSubject) ?? "",
            showLocalTimelineForAnonymous: settingsFromDb.getBool(.showLocalTimelineForAnonymous) ?? false,
            showTrendingForAnonymous: settingsFromDb.getBool(.showTrendingForAnonymous) ?? false,
            showEditorsChoiceForAnonymous: settingsFromDb.getBool(.showEditorsChoiceForAnonymous) ?? false,
            showEditorsUsersChoiceForAnonymous: settingsFromDb.getBool(.showEditorsUsersChoiceForAnonymous) ?? false,
            showHashtagsForAnonymous: settingsFromDb.getBool(.showHashtagsForAnonymous) ?? false,
            showCategoriesForAnonymous: settingsFromDb.getBool(.showCategoriesForAnonymous) ?? false,
            showNews: settingsFromDb.getBool(.showNews) ?? false,
            showSharedBusinessCards: settingsFromDb.getBool(.showSharedBusinessCards) ?? false
        )
        
        return applicationSettings
    }
}
