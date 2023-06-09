//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

public enum EventType: String, Codable, CaseIterable {
    case accountLogin
    case accountRefresh
    case accountConfirm
    case accountChangePassword
    case accountRevoke
    
    case authClientsCreate
    case authClientsList
    case authClientsRead
    case authClientsUpdate
    case authClientsDelete
    
    case forgotToken
    case forgotConfirm
    
    case registerNewUser
    case registerUserName
    case registerEmail
    
    case rolesCreate
    case rolesList
    case rolesRead
    case rolesUpdate
    case rolesDelete
    
    case userRolesConnect
    case userRolesDisconnect
    
    case usersRead
    case usersUpdate
    case usersDelete
    
    case settingsList
    case settingsRead
    case settingsUpdate
    
    case activityPubRead
    case activityPubInbox
    case activityPubOutbox
    case activityPubFollowing
    case activityPubFollowers
    case activityPubLiked
    case activityPubSharedInbox
    
    case webfinger
    case nodeinfo
    case hostMeta
    
    case search
}

final class Event: Model {

    static let schema = "Events"
    
    @ID(custom: .id, generatedBy: .user)
    var id: UInt64?
    
    @Field(key: "type")
    var type: EventType
  
    @Field(key: "method")
    var method: String
    
    @Field(key: "uri")
    var uri: String
    
    @Field(key: "wasSuccess")
    var wasSuccess: Bool
    
    @Field(key: "userId")
    var userId: UInt64?
    
    @Field(key: "requestBody")
    var requestBody: String?
    
    @Field(key: "responseBody")
    var responseBody: String?

    @Field(key: "error")
    var error: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() { }
    
    init(id: UInt64? = nil,
         type: EventType,
         method: HTTPMethod,
         uri: String,
         wasSuccess: Bool,
         userId: UInt64? = nil,
         requestBody: String? = nil,
         responseBody: String? = nil,
         error: String? = nil
    ) {
        self.id = id ?? Frostflake.generate()
        self.type = type
        self.method = method.rawValue
        self.uri = uri
        self.wasSuccess = wasSuccess
        self.userId = userId
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.error = error
    }
}

/// Allows `Log` to be encoded to and decoded from HTTP messages.
extension Event: Content { }
