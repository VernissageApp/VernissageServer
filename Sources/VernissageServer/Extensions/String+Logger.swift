//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Logging

extension String {
    public func loggerMetadata() -> Logger.MetadataValue {
        return Logger.MetadataValue(stringLiteral: self)
    }
}
