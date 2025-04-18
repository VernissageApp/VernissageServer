//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import SotoCore
import SotoSNS

public extension Request {

    var objectStorage: ObjectStorage {
        .init(request: self)
    }

    struct ObjectStorage {
        var client: AWSClient? {
            return request.application.objectStorage.client
        }
        
        let request: Request
    }
}
