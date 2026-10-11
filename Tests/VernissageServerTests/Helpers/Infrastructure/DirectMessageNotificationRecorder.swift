//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

/// Records transaction boundaries without sending pushes to an external service.
actor DirectMessageNotificationRecorder {
    private var savedInTransaction: [Bool] = []
    private var dispatchedInTransaction: [Bool] = []

    func saved(inTransaction: Bool) {
        savedInTransaction.append(inTransaction)
    }

    func dispatched(inTransaction: Bool) {
        dispatchedInTransaction.append(inTransaction)
    }

    func snapshot() -> (saved: [Bool], dispatched: [Bool]) {
        (savedInTransaction, dispatchedInTransaction)
    }
}
