//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoUsageUsersDto {
    public let total: Int
    public let activeMonth: Int
    public let activeHalfyear: Int
    
    public init(total: Int, activeMonth: Int, activeHalfyear: Int) {
        self.total = total
        self.activeMonth = activeMonth
        self.activeHalfyear = activeHalfyear
    }
}

extension NodeInfoUsageUsersDto: Codable { }
