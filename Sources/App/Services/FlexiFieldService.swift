//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct FlexiFieldServiceKey: StorageKey {
        typealias Value = FlexiFieldServiceType
    }

    var flexiFieldService: FlexiFieldServiceType {
        get {
            self.application.storage[FlexiFieldServiceKey.self] ?? FlexiFieldService()
        }
        nonmutating set {
            self.application.storage[FlexiFieldServiceKey.self] = newValue
        }
    }
}

protocol FlexiFieldServiceType {
    func getFlexiFields(on request: Request, for userId: Int64) async throws -> [FlexiField]
}

final class FlexiFieldService: FlexiFieldServiceType {

    func getFlexiFields(on request: Request, for userId: Int64) async throws -> [FlexiField] {
        return try await FlexiField.query(on: request.db).filter(\.$user.$id == userId).sort(\.$id).all()
    }
}
