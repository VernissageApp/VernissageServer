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

@_documentation(visibility: private)
protocol FlexiFieldServiceType {
    func getFlexiFields(on database: Database, for userId: Int64) async throws -> [FlexiField]
    func dispatchUrlValidator(on request: Request, flexiFields: [FlexiField]) async throws
}

/// A service for managing additional user fields.
final class FlexiFieldService: FlexiFieldServiceType {

    func getFlexiFields(on database: Database, for userId: Int64) async throws -> [FlexiField] {
        return try await FlexiField.query(on: database).filter(\.$user.$id == userId).sort(\.$id).all()
    }
    
    func dispatchUrlValidator(on request: Request, flexiFields: [FlexiField]) async throws {
        for flexiField in flexiFields {
            // Process only fields which contains correct urls.
            if flexiField.value?.lowercased().contains("https://") == false {
                continue
            }
            
            try await request
                .queues(.urlValidator)
                .dispatch(UrlValidatorJob.self, flexiField, maxRetryCount: 3)
        }
    }
}
