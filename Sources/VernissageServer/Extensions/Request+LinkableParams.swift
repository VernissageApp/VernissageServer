//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues

extension Request {

    func linkableParams() -> LinkableParams {
        let minId: String? = self.query["minId"]
        let maxId: String? = self.query["maxId"]
        let sinceId: String? = self.query["sinceId"]
        let limit: Int = self.query["limit"] ?? 40
        
        return LinkableParams(maxId: maxId, minId: minId, sinceId: sinceId, limit: min(limit, 40))
    }
}


