//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension QueryBuilder<Status> {
    func filter(id: Int64?) -> Self {
        guard let id else {
            return self
        }
        
        return self.filter(\.$id == id)
    }
}
