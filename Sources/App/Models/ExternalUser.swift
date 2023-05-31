import Fluent
import Vapor

final class ExternalUser: Model {
    static let schema = "ExternalUsers"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "type")
    var type: AuthClientType
    
    @Field(key: "externalId")
    var externalId: String
    
    @Field(key: "authenticationToken")
    var authenticationToken: String?
    
    @Field(key: "tokenCreatedAt")
    var tokenCreatedAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         type: AuthClientType,
         externalId: String,
         userId: UUID
    ) {
        self.id = id
        self.type = type
        self.externalId = externalId
        self.$user.id = userId
    }
}

/// Allows `ExternalUser` to be encoded to and decoded from HTTP messages.
extension ExternalUser: Content { }
