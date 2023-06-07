//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension Application.Services {
    struct ActivityPubServiceKey: StorageKey {
        typealias Value = ActivityPubServiceType
    }

    var activityPubService: ActivityPubServiceType {
        get {
            self.application.storage[ActivityPubServiceKey.self] ?? ActivityPubService()
        }
        nonmutating set {
            self.application.storage[ActivityPubServiceKey.self] = newValue
        }
    }
}

protocol ActivityPubServiceType {
    func delete(activity: ActivityDto) throws
    func follow(activity: ActivityDto) throws
    func accept(activity: ActivityDto) throws
}

final class ActivityPubService: ActivityPubServiceType {
    public func delete(activity: ActivityDto) throws {
    }
    
    public func follow(activity: ActivityDto) throws {
    }
    
    public func accept(activity: ActivityDto) throws {
    }
}
