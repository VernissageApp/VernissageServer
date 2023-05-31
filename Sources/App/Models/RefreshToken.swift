import Fluent
import Vapor

final class RefreshToken: Model {

    static let schema = "RefreshTokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "expiryDate")
    var expiryDate: Date
    
    @Field(key: "revoked")
    var revoked: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Parent(key: "userId")
    var user: User
    
    init() { }
    
    init(id: UUID? = nil,
         userId: UUID,
         token: String,
         expiryDate: Date,
         revoked: Bool = false
    ) {
        self.id = id
        self.token = token
        self.expiryDate = expiryDate
        self.revoked = revoked
        self.$user.id = userId
    }
}

/// Allows `RefreshToken` to be encoded to and decoded from HTTP messages.
extension RefreshToken: Content { }
