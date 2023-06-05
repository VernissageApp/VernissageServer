//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Request.Body {
    public var wholeData: Data? {
        if var data = self.data {
            return data.readData(length: data.readableBytes)
        } else {
            return nil
        }
    }
}
