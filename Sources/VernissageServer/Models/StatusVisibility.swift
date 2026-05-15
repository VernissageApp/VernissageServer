//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Status visibility.
enum StatusVisibility: Int, Codable {
    /// A `public` status is visible to everyone. It can be viewed by logged-in users, users on other servers,
    /// and often by visitors who are not logged in, depending on the instance configuration.
    /// Public posts may appear on public timelines, such as the local timeline or federated timeline,
    /// and they can generally be boosted by other users.
    case `public` = 1
    
    /// A `followers` status is visible only to the author’s followers and to any users mentioned in the post.
    /// It does not appear on public timelines and is not publicly accessible to arbitrary users.
    /// Other users generally cannot boost it, although the author may still be able to boost their own post.
    case followers = 2
    
    /// A `mentioned` status is visible only to users explicitly mentioned in the post.
    /// This should not be treated as a secure private message.
    case mentioned = 3
    
    /// An `quietPublic` status is still public, but it is not promoted to public timelines.
    /// Anyone who visits the author’s profile, has a direct link, or sees the post through interactions may
    /// be able to view it. However, it should not appear in public timelines such as the local or federated timeline.
    case quietPublic = 4
}
