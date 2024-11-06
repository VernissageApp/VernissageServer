//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues
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
protocol FlexiFieldServiceType: Sendable {
    func getFlexiFields(for userId: Int64, on database: Database) async throws -> [FlexiField]
    func dispatchUrlValidator(flexiFields: [FlexiField], on context: ExecutionContext) async throws
}

/// A service for managing additional user fields.
final class FlexiFieldService: FlexiFieldServiceType {

    func getFlexiFields(for userId: Int64, on database: Database) async throws -> [FlexiField] {
        return try await FlexiField.query(on: database).filter(\.$user.$id == userId).sort(\.$id).all()
    }
        
    func dispatchUrlValidator(flexiFields: [FlexiField], on context: ExecutionContext) async throws {
        for flexiField in flexiFields {
            // Process only fields which contains correct urls.
            if flexiField.value?.lowercased().contains("https://") == false {
                continue
            }
            
            try await context
                .queues(.urlValidator)
                .dispatch(UrlValidatorJob.self, flexiField, maxRetryCount: 3)
        }
    }
}
