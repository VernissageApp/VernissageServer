//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SotoS3
import Vapor

public extension Application {
    var objectStorage: ObjectStorage {
        .init(application: self)
    }

    struct ObjectStorage {
        struct ClientKey: StorageKey {
            typealias Value = AWSClient
        }

        public var client: AWSClient? {
            get {
                return self.application.storage[ClientKey.self]
            }

            nonmutating set {
                self.application.storage.set(ClientKey.self, to: newValue) {
                    try $0.syncShutdown()
                }
            }
        }

        struct ServiceKey<T>: StorageKey {
            typealias Value = T
        }

        func getService<T>() -> T {
            return getService(key: ServiceKey<T>.self)
        }

        func setService<T>(_ service: T) {
            setService(service, key: ServiceKey<T>.self)
        }

        func getService<T, Key: StorageKey>(key: Key.Type) -> T where Key.Value == T {
            guard let service = self.application.storage[Key.self] else {
                fatalError("\(T.self) not setup. Use application.aws.client = ...")
            }
            return service
        }

        func setService<T, Key: StorageKey>(_ service: T, key: Key.Type) where Key.Value == T {
            self.application.storage[Key.self] = service
        }

        let application: Application
    }
}

extension Application.ObjectStorage {
    struct S3Key: StorageKey {
        typealias Value = S3
    }

    public var s3: S3? {
        get {
            return self.application.storage[S3Key.self]
        }

        nonmutating set {
            self.application.storage[S3Key.self] = newValue
        }
    }
}

public extension Request.ObjectStorage {
    var s3: S3? {
        return request.application.objectStorage.s3
    }
}