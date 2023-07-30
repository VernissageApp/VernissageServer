//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues

extension HTTPHeaders {

    func dictionary() -> [String: String] {
        var headers: [String: String] = [:]
        for header in self {
            headers[header.name] = header.value
        }
        
        return headers
    }
}


