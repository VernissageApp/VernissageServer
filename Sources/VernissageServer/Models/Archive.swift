//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Archive requested by user.
final class Archive: Model, @unchecked Sendable {
    static let schema: String = "Archives"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
        
    @Field(key: "requestDate")
    var requestDate: Date

    @Field(key: "startDate")
    var startDate: Date?

    @Field(key: "endDate")
    var endDate: Date?
    
    @Field(key: "fileName")
    var fileName: String?
    
    @Field(key: "status")
    var status: ArchiveStatus
    
    @Field(key: "errorMessage")
    var errorMessage: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, userId: Int64) {
        self.init()

        self.id = id
        self.requestDate = Date()
        self.status = .new
        self.$user.id = userId
    }
}

/// Allows `Archive` to be encoded to and decoded from HTTP messages.
extension Archive: Content { }
