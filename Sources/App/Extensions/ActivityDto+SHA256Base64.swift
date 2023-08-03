//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import ActivityPubKit
import Vapor

extension ActivityDto {
    public func getSHA256Base64String() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        let bodySHA256 = SHA256.hash(data: jsonData)
        return Data(bodySHA256).base64String()
    }
}
