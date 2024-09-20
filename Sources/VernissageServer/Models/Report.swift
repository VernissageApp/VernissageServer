//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Fluent
import Vapor

/// User report.
final class Report: Model, @unchecked Sendable {
    static let schema = "Reports"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "reportedUserId")
    var reportedUser: User
    
    @OptionalParent(key: "statusId")
    var status: Status?
    
    @Field(key: "comment")
    var comment: String?
    
    @Field(key: "forward")
    var forward: Bool
    
    @Field(key: "category")
    var category: String?
    
    @Field(key: "ruleIds")
    var ruleIds: String?
    
    @Field(key: "considerationDate")
    var considerationDate: Date?
    
    @OptionalParent(key: "considerationUserId")
    var considerationUser: User?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     userId: Int64,
                     reportedUserId: Int64,
                     statusId: Int64?,
                     comment: String?,
                     forward: Bool,
                     category: String?,
                     ruleIds: [Int]?,
                     considerationDate: Date? = nil,
                     considerationUserId: Int64? = nil
    ) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$reportedUser.id = reportedUserId
        self.$status.id = statusId
        
        self.comment = comment
        self.forward = forward
        self.category = category
                
        if let ruleIds {
            self.ruleIds = ruleIds.map({ "\($0)" }).joined(separator: ",")
        }
        
        self.considerationDate = considerationDate
        self.$considerationUser.id = considerationUserId
    }
}

/// Allows `Report` to be encoded to and decoded from HTTP messages.
extension Report: Content { }
