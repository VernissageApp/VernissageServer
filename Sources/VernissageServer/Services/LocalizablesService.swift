//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct LocalizablesServiceKey: StorageKey {
        typealias Value = LocalizablesServiceType
    }

    var localizablesService: LocalizablesServiceType {
        get {
            self.application.storage[LocalizablesServiceKey.self] ?? LocalizablesService()
        }
        nonmutating set {
            self.application.storage[LocalizablesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol LocalizablesServiceType {
    func get(on database: Database, code: String, locale: String) async throws -> String
    func get(on database: Database, code: String, locale: String, variables: [String:String]?) async throws -> String
}

/// A service for managing location resources in the system.
final class LocalizablesService: LocalizablesServiceType {

    func get(on database: Database, code: String, locale: String) async throws -> String {
        return try await self.get(on: database, code: code, locale: locale, variables: nil)
    }
    
    func get(on database: Database, code: String, locale: String, variables: [String:String]?) async throws -> String {
        let localizable = try await Localizable.query(on: database).group(.and) { localeGroup in
            localeGroup.filter(\.$code == code)
            localeGroup.filter(\.$locale == locale)
        }.first()
        
        guard let localizable else {
            return code
        }
        
        var localizabedString = localizable.user ?? localizable.system
        guard let variables else {
            return localizabedString
        }
        
        for item in variables {
            localizabedString = localizabedString.replacingOccurrences(of: "{\(item.key)}", with: item.value)
        }
        
        return localizabedString
    }
}
