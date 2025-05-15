//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import SotoCore
import SotoSNS

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

        struct ServiceKey<T: Sendable>: StorageKey {
            typealias Value = T
        }

        func getService<T: Sendable>() -> T {
            return getService(key: ServiceKey<T>.self)
        }

        func setService<T: Sendable>(_ service: T) {
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
    }
    
    public func setS3(_ s3: S3) async {
        await self.application.storage.setWithAsyncShutdown(S3Key.self, to: s3) { s in
            try? await s.client.httpClient.shutdown()
        }
    }
}

public extension Request.ObjectStorage {
    var s3: S3? {
        return request.application.objectStorage.s3
    }
}
