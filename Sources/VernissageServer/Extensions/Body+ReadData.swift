//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension Request.Body {
    public var wholeData: Data? {
        if var data = self.data {
            return data.readData(length: data.readableBytes)
        } else {
            return nil
        }
    }
    
    public var bodyValue: String {
        return self.string ?? ""
    }
    
    func activity() throws -> ActivityDto? {
        // Activity without any data, strange...
        guard let data = self.wholeData else {
            return nil
        }
        
        // Activity with not recognized JSON structure.
        guard let activityDto = try? JSONDecoder().decode(ActivityDto.self, from: data) else {
            return nil
        }
        
        return activityDto
    }
}
