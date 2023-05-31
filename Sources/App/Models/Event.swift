import Fluent
import Vapor

public enum EventType: String, Codable, CaseIterable {
    case accountLogin
    case accountRefresh
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
    case registerConfirm
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
}

final class Event: Model {

    static let schema = "Events"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "type")
    var type: EventType
  
    @Field(key: "method")
    var method: String
    
    @Field(key: "uri")
    var uri: String
    
    @Field(key: "wasSuccess")
    var wasSuccess: Bool
    
    @Field(key: "userId")
    var userId: UUID?
    
    @Field(key: "requestBody")
    var requestBody: String?
    
    @Field(key: "responseBody")
    var responseBody: String?

    @Field(key: "error")
    var error: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() { }
    
    init(id: UUID? = nil,
         type: EventType,
         method: HTTPMethod,
         uri: String,
         wasSuccess: Bool,
         userId: UUID? = nil,
         requestBody: String? = nil,
         responseBody: String? = nil,
         error: String? = nil
    ) {
        self.id = id
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
