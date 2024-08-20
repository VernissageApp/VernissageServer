//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension String {
    public func host() -> String {
        return URLComponents(string: self)?.host ?? ""
    }
    
    public func fileName() -> String {
        return String(self.split(separator: "/").last ?? "")
    }
}
