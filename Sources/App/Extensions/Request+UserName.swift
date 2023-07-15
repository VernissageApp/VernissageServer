//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import ExtendedConfiguration

extension Request {
    public var userId: Int64? {
        return self.auth.get(UserPayload.self)?.id.toId()
    }
    
    public var userName: String {
        return self.auth.get(UserPayload.self)?.userName ?? ""
    }
    
    public var userNameNormalized: String {
        return self.auth.get(UserPayload.self)?.userName.uppercased() ?? ""
    }
}
