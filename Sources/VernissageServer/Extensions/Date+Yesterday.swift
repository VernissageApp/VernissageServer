//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Date {
    public static var yesterday: Date {
        return Date.now.addingTimeInterval(-86400)
    }

    public static func ago(days: Int) -> Date {
        if let ago = Calendar.current.date(byAdding: .day, value: -days, to: Date()) {
            return ago
        }
        
        return Date.now.addingTimeInterval(TimeInterval(-86400 * days))
    }
    
    public static var fiveMinutesAgo: Date {
        if let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: Date()) {
            return fiveMinutesAgo
        }
        
        return Date.now.addingTimeInterval(-300)
    }
    
    public static var fifteenMinutesAgo: Date {
        if let fifteenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -15, to: Date()) {
            return fifteenMinutesAgo
        }
        
        return Date.now.addingTimeInterval(-900)
    }

    public static var hourAgo: Date {
        if let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) {
            return hourAgo
        }
        
        return Date.now.addingTimeInterval(-3600)
    }
    
    public static var weekAgo: Date {
        if let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) {
            return weekAgo
        }
        
        return Date.now.addingTimeInterval(-2592000)
    }
    
    public static var monthAgo: Date {
        if let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) {
            return monthAgo
        }
        
        return Date.now.addingTimeInterval(-2592000)
    }
    
    public static var halfYearAgo: Date {
        if let halfYearAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) {
            return halfYearAgo
        }
        
        return Date.now.addingTimeInterval(-15552000)
    }
    
    public static var yearAgo: Date {
        if let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) {
            return yearAgo
        }
        
        return Date.now.addingTimeInterval(-31104000)
    }
    
    public static var futureYear: Date {
        if let futureYear = Calendar.current.date(byAdding: .year, value: 1, to: Date()) {
            return futureYear
        }
        
        return Date.now.addingTimeInterval(31104000)
    }
}
