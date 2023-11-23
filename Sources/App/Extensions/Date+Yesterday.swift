//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Date {
    public static var yesterday: Date {
        return Date.now.addingTimeInterval(-86400)
    }
    
    public static var monthAgo: Date {
        if let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) {
            return monthAgo
        }
        
        return Date.now.addingTimeInterval(-2592000)
    }
    
    public static var yearAgo: Date {
        if let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) {
            return yearAgo
        }
        
        return Date.now.addingTimeInterval(-31104000)
    }
}
