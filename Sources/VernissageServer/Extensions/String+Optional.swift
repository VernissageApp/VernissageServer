//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}
