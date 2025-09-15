//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createStatusActivityPubEvent(statusId: Int64,
                                      userId: Int64,
                                      type: StatusActivityPubEventType,
                                      numberOfSuccessItems: Int = 1,
                                      numberOfErrorItems: Int = 0) async throws -> StatusActivityPubEvent {
        let newStatusActivityPubEventId = await ApplicationManager.shared.generateId()
        let statusActivityPubEvent = StatusActivityPubEvent(id: newStatusActivityPubEventId, statusId: statusId, userId: userId, type: type)
        try await statusActivityPubEvent.save(on: self.db)
        
        for index in 0..<numberOfSuccessItems {
            let newStatusActivityPubEventItemId = await ApplicationManager.shared.generateId()
            let statusActivityPubEventItem = StatusActivityPubEventItem(id: newStatusActivityPubEventItemId,
                                                                        statusActivityPubEventId: newStatusActivityPubEventId,
                                                                        url: "https://localhost/shared-status/\(index)")
            try await statusActivityPubEventItem.save(on: self.db)
        }
        
        for index in 0..<numberOfErrorItems {
            let newStatusActivityPubEventItemId = await ApplicationManager.shared.generateId()
            let statusActivityPubEventItem = StatusActivityPubEventItem(id: newStatusActivityPubEventItemId,
                                                                        statusActivityPubEventId: newStatusActivityPubEventId,
                                                                        url: "https://localhost/shared-status/\(index)")
            statusActivityPubEventItem.isSuccess = false
            statusActivityPubEventItem.errorMessage = "Error"

            try await statusActivityPubEventItem.save(on: self.db)
        }
        
        return statusActivityPubEvent
    }
    
    func getStatusActivityPubEvents(userId: Int64) async throws -> [StatusActivityPubEvent] {
        return try await StatusActivityPubEvent.query(on: self.db)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func getStatusActivityPubEvents(statusId: Int64) async throws -> [StatusActivityPubEvent] {
        return try await StatusActivityPubEvent.query(on: self.db)
            .filter(\.$status.$id == statusId)
            .all()
    }
}
