//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum ObjectTypeDto: String {
    case accept = "Accept"
    case add = "Add"
    case announce = "Announce"
    case arrive = "Arrive"
    case block = "Block"
    case create = "Create"
    case delete = "Delete"
    case dislike = "Dislike"
    case flag = "Flag"
    case follow = "Follow"
    case ignore = "Ignore"
    case invite = "Invite"
    case join = "Join"
    case leave = "Leave"
    case like = "Like"
    case listen = "Listen"
    case move = "Move"
    case offer = "Offer"
    case question = "Question"
    case reject = "Reject"
    case read = "Read"
    case remove = "Remove"
    case tentativeReject = "TentativeReject"
    case tentativeAccept = "TentativeAccept"
    case travel = "Travel"
    case undo = "Undo"
    case update = "Update"
    case view = "View"

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

extension ObjectTypeDto: Codable { }
extension ObjectTypeDto: Sendable { }
