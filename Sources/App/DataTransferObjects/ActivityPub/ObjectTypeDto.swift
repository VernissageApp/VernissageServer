//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum ObjectTypeDto: String, Content {
    case article = "Article"
    case audio = "Audio"
    case document = "Document"
    case event = "Event"
    case image = "Image"
    case note = "Note"
    case page = "Page"
    case place = "Place"
    case profile = "Profile"
    case relationship = "Relationship"
    case tombstone = "Tombstone"
    case video = "Video"
}
