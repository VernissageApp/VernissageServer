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
    /// Retrieves all flexible fields (custom user fields) for a specific user.
    ///
    /// - Parameters:
    ///   - userId: The user Id for whom to retrieve flexible fields.
    ///   - database: The database connection to use.
    /// - Returns: An array of flexible fields associated with the user.
    /// - Throws: An error if the database query fails.
    func getFlexiFields(for userId: Int64, on database: Database) async throws -> [FlexiField]

    /// Dispatches validation jobs for URLs found in the provided flexible fields.
    ///
    /// - Parameters:
    ///   - flexiFields: The flexible fields containing URLs to validate.
    ///   - context: The execution context providing access to services and job queues.
    /// - Throws: An error if dispatching validation jobs fails.
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
