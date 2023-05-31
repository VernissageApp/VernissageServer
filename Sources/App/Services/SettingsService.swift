import Vapor
import Fluent

extension Application.Services {
    struct SettingsServiceKey: StorageKey {
        typealias Value = SettingsServiceType
    }

    var settingsService: SettingsServiceType {
        get {
            self.application.storage[SettingsServiceKey.self] ?? SettingsService()
        }
        nonmutating set {
            self.application.storage[SettingsServiceKey.self] = newValue
        }
    }
}

protocol SettingsServiceType {
    func get(on application: Application) -> EventLoopFuture<[Setting]>
}

final class SettingsService: SettingsServiceType {

    func get(on application: Application) -> EventLoopFuture<[Setting]> {

        application.logger.info("Downloading application settings from database")

        return Setting.query(on: application.db).all()
    }
}
