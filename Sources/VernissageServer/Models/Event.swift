//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Events that occurs in the system.
enum EventType: String, Codable, CaseIterable {
    case unknown

    case accountLogin
    case accountLogout
    case accountRefresh
    case accountConfirm
    case accountIsEmailVerified
    case accountChangeEmail
    case accountChangePassword
    case accountForgotToken
    case accountForgotConfirm
    case accountRevoke
    case accountGetTwoFactorToken
    case accountEnableTwoFactorAuthentication
    case accountDisableTwoFactorAuthentication
    
    case authClientsCreate
    case authClientsList
    case authClientsRead
    case authClientsUpdate
    case authClientsDelete
    
    case authDynamicClientsCreate
    
    case oAuthAuthenticate
    case oAuthAuthenticateCallback
    case oAuthToken
    
    case registerNewUser
    case registerUserName
    case registerEmail
    
    case rolesCreate
    case rolesList
    case rolesRead
    case rolesUpdate
    case rolesDelete
    
    case usersList
    case usersRead
    case usersUpdate
    case usersDelete
    case usersFollow
    case usersUnfollow
    case usersFollowers
    case usersFollowing
    case usersMute
    case usersUnmute
    case usersEnable
    case usersDisable
    case userRolesConnect
    case userRolesDisconnect
    case userApprove
    case userReject
    case userFeature
    case userUnfeature
    case usersStatuses
    case usersRemoveOneTimePassword
    
    case avatarUpdate
    case avatarDelete

    case headerUpdate
    case headerDelete
    
    case attachmentsCreate
    case attachmentsHdrCreate
    case attachmentsHdrDelete
    case attachmentsUpdate
    case attachmentsDelete
    case attachmentsDescribe
    case attachmentsHashtags
    
    case settingsList
    case settingsPublic
    case settingsUpdate
    
    case activityPubRead
    case activityPubInbox
    case activityPubOutbox
    case activityPubFollowing
    case activityPubFollowers
    case activityPubLiked
    case activityPubSharedInbox
    case activityPubStatus
    
    case webfinger
    case nodeinfo
    case hostMeta
    case instance
    
    case countriesList
    case locationsList
    case locationsRead
    
    case categoriesList
    case categoriesCreate
    case categoriesUpdate
    case categoriesDelete
    case categoriesEnable
    case categoriesDisable
    
    case licensesList
    
    case statusesList
    case statusesCreate
    case statusesRead
    case statusesUpdate
    case statusesDelete
    case statusesUnlist
    case statusesApplyContentWarning
    case statusesReblog
    case statusesUnreblog
    case statusesFavourite
    case statusesUnfavourite
    case statusesBookmark
    case statusesUnbookmark
    case statusesFeature
    case statusesUnfeature
    case statusesContext
    case statusesReblogged
    case statusesFavourited
    
    case timelinesPublic
    case timelinesCategories
    case timelinesHashtags
    case timelinesFeaturedStatuses
    case timelinesFeaturedUsers
    case timelinesHome
    
    case followRequestList
    case followRequestApprove
    case followRequestReject
    
    case notificationsList
    case notificationsCount
    case notificationsUpdateMarker
    
    case relationships
    case search
    case invitationList
    case invitationGenerate
    case invitationDelete
    
    case reportsCreate
    case reportsList
    case reportsClose
    case reportsRestore
    
    case trendingStatuses
    case trendingUsers
    case trendingHashtags
    
    case bookmarksList
    case favouritesList
    
    case instanceBlockedDomainsList
    case instanceBlockedDomainsCreate
    case instanceBlockedDomainsUpdate
    case instanceBlockedDomainsDelete
    
    case pushSubscriptionsList
    case pushSubscriptionsCreate
    case pushSubscriptionsUpdate
    case pushSubscriptionsDelete

    case rulesList
    case rulesCreate
    case rulesUpdate
    case rulesDelete
    
    case userAliasesList
    case userAliasesCreate
    case userAliasesDelete
    
    case actorRead
    case healthRead
    
    case errorList
    case errorRead
    case errorCreate
    case errorDelete
    
    case archivesList
    case archivesCreate
    
    case exportsFollowing
    case exportsBookmarks
    
    case userSettingsList
    case userSettingsRead
    case userSettingsSet
    case userSettingsDelete
    
    case rssUser
    case rssLocal
    case rssGlobal
    case rssTrending
    case rssFeatured
    case rssCategories
    case rssHashtags
    
    case atomUser
    case atomLocal
    case atomGlobal
    case atomTrending
    case atomFeatured
    case atomCategories
    case atomHashtags
    
    case followImportsList
    case followImportsUpload
    
    case articlesList
    case articlesRead
    case articlesCreate
    case articlesUpdate
    case articlesDelete
    case articlesDismiss

    case businessCardsRead
    case businessCardsCreate
    case businessCardsUpdate
    case businessCardsAvatar
    
    case sharedBusinessCardList
    case sharedBusinessCardRead
    case sharedBusinessCardCreate
    case sharedBusinessCardUpdate
    case sharedBusinessCardDelete
    case sharedBusinessCardMessage
    case sharedBusinessCardRevoke
    case sharedBusinessCardUnrevoke
    case sharedBusinessCardReadByThirdParty
    case sharedBusinessCardUpdateByThirdParty
    case sharedBusinessCardMessageByThirdParty
    
    case quickCaptchaGenerate
}

final class Event: Model, @unchecked Sendable {

    static let schema = "Events"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "type")
    var type: EventType
  
    @Field(key: "method")
    var method: String
    
    @Field(key: "uri")
    var uri: String
    
    @Field(key: "wasSuccess")
    var wasSuccess: Bool
    
    @Field(key: "userId")
    var userId: Int64?
    
    @Field(key: "requestBody")
    var requestBody: String?
    
    @Field(key: "responseBody")
    var responseBody: String?

    @Field(key: "error")
    var error: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Field(key: "userAgent")
    var userAgent: String?
    
    init() { }
    
    convenience init(id: Int64,
                     type: EventType,
                     method: HTTPMethod,
                     uri: String,
                     wasSuccess: Bool,
                     userId: Int64? = nil,
                     requestBody: String? = nil,
                     responseBody: String? = nil,
                     error: String? = nil,
                     userAgent: String? = nil
    ) {
        self.init()

        self.id = id
        self.type = type
        self.method = method.rawValue
        self.uri = uri
        self.wasSuccess = wasSuccess
        self.userId = userId
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.error = error
        self.userAgent = userAgent
    }
}

/// Allows `Log` to be encoded to and decoded from HTTP messages.
extension Event: Content { }
