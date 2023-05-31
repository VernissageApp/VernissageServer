@testable import App
import Vapor
import Fluent

extension Setting {
    static func get(key: SettingKey) throws -> Setting {
        guard let setting = try Setting.query(on: SharedApplication.application().db).filter(\.$key == key.rawValue).first().wait() else {
            throw SharedApplicationError.unwrap
        }

        return setting
    }
}
