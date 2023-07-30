//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension Request.Body {
    func hash() -> String? {
        guard let data = self.wholeData else {
            return nil
        }
        
        let bodySha256 = SHA256.hash(data: data)
        return Data(bodySha256).base64String()
    }
}
