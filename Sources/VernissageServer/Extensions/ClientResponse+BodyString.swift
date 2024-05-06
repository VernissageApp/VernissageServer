//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension ClientResponse {
    public var wholeData: Data? {
        if var data = self.body {
            return data.readData(length: data.readableBytes)
        } else {
            return nil
        }
    }
    
    public var bodyValue: String {
        guard let wholeData = self.wholeData else {
            return "<empty body>"
        }
        return String(data: wholeData, encoding: .utf8) ?? "<body not decoded>"
    }
}
