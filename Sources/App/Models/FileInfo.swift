//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class FileInfo: Model {
    static let schema: String = "FileInfos"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "fileName")
    var fileName: String
    
    @Field(key: "width")
    var width: Int
    
    @Field(key: "height")
    var height: Int
    
//    @OptionalChild(for: \.$originalFile)
//    var attachmentOrginalFile: Attachment
//
//    @OptionalChild(for: \.$smallFile)
//    var attachmentSmallFile: Attachment
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil,
                     fileName: String,
                     width: Int,
                     height: Int) {
        self.init()

        self.fileName = fileName
        self.width = width
        self.height = height
    }
}

/// Allows `File` to be encoded to and decoded from HTTP messages.
extension File: Content { }
