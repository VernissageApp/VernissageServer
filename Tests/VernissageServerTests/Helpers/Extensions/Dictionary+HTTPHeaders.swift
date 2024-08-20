//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent
import ActivityPubKit

extension [Header: String] {
    func getHTTPHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders()

        self.forEach { (key: Header, value: String) in
            headers.add(name: key.rawValue, value: value)
        }
        
        return headers
    }
}
