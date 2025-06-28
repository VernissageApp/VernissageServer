//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
@preconcurrency import SwiftGD
@preconcurrency import Frostflake

extension Application.Services {
    struct QuickCaptchaServiceKey: StorageKey {
        typealias Value = QuickCaptchaServiceType
    }

    var quickCaptchaService: QuickCaptchaServiceType {
        get {
            self.application.storage[QuickCaptchaServiceKey.self] ?? QuickCaptchaService()
        }
        nonmutating set {
            self.application.storage[QuickCaptchaServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol QuickCaptchaServiceType: Sendable {
    func generate(key: String, on context: ExecutionContext) async throws -> Data
    func validate(token: String, on context: ExecutionContext) async throws -> Bool
    func clear(on database: Database) async throws
}

/// A service for generating captcha images (6 letters with distrubtors).
final class QuickCaptchaService: QuickCaptchaServiceType {

#if os(Linux)
    private let fontList = ["/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"]
#else
    private let fontList = ["SFCompact"]
#endif
    
    private let colors = [
        Color(red: 9 / 255.0, green: 18 / 255.0, blue: 44 / 255.0, alpha: 1),
        Color(red: 135 / 255.0, green: 35 / 255.0, blue: 65 / 255.0, alpha: 1),
        Color(red: 190 / 255.0, green: 49 / 255.0, blue: 68 / 255.0, alpha: 1),
        Color(red: 225 / 255.0, green: 117 / 255.0, blue: 100 / 255.0, alpha: 1),
        Color(red: 82 / 255.0, green: 34 / 255.0, blue: 88 / 255.0, alpha: 1),
        Color(red: 140 / 255.0, green: 48 / 255.0, blue: 97 / 255.0, alpha: 1),
        Color(red: 198 / 255.0, green: 60 / 255.0, blue: 81 / 255.0, alpha: 1),
        Color(red: 217 / 255.0, green: 95 / 255.0, blue: 89 / 255.0, alpha: 1),
        Color(red: 9 / 255.0, green: 38 / 255.0, blue: 53 / 255.0, alpha: 1),
        Color(red: 92 / 255.0, green: 131 / 255.0, blue: 116 / 255.0, alpha: 1),
        Color(red: 158 / 255.0, green: 200 / 255.0, blue: 185 / 255.0, alpha: 1)
    ]
    
    public func generate(key: String, on context: ExecutionContext) async throws -> Data {
        let quickCaptchaFromDatabase = try await QuickCaptcha.query(on: context.db)
            .filter(\.$key == key)
            .first()
        
        // Generate new text or use text genereted for specific key for the user to guess.
        let text = if let quickCaptchaFromDatabase  {
            quickCaptchaFromDatabase.text
        } else {
            self.createRandomText(length: 6)
        }
        
        // Generate image that should be shown to user.
        let image = try self.createImage(text: text)
        
        // Crete item about captcha information in database (only when key not exists).
        if quickCaptchaFromDatabase == nil {
            let newId = context.application.services.snowflakeService.generate()
            let quickCaptcha = QuickCaptcha(id: newId, key: key, text: text)
            try await quickCaptcha.save(on: context.db)
        }
        
        return image
    }
    
    public func validate(token: String, on context: ExecutionContext) async throws -> Bool {
        let parts = token.split(separator: "/")
        guard parts.count == 2 else {
            return false
        }
        
        let quickCaptchaFromDatabase = try await QuickCaptcha.query(on: context.db)
            .filter(\.$key == String(parts[0]))
            .first()
        
        guard let quickCaptchaFromDatabase else {
            return false
        }
        
        return quickCaptchaFromDatabase.text == String(parts[1])
    }
    
    public func clear(on database: Database) async throws {
        let hourAgo = Date.hourAgo

        try await  QuickCaptcha.query(on: database)
            .filter(\.$createdAt < hourAgo)
            .delete()
    }
    
    private func createImage(text: String) throws -> Data {
        guard let img = Image(width: 220, height: 60) else {
            throw Abort(.internalServerError)
        }
        
        
        let chars = Array(text)
        let spacing = 30
        
        // Render background.
        img.fillRectangle(topLeft: .zero,
                          bottomRight: Point(x: 219, y: 59),
                          color: .white)
        
        // Render characters.
        for (index, char) in chars.enumerated() {
            let x = 25 + (index * spacing)
            let y = Int.random(in: 35...45)
            let rotate = Double.random(in: -20...20)
            
            img.renderText("\(char)",
                           from: Point(x: x, y: y),
                           fontList: self.fontList,
                           color: self.colors.randomElement() ?? .blue,
                           size: 24,
                           angle: .degrees(rotate))
        }
        
        // Render lines.
        img.drawLine(from: .init(x: 10, y: 20), to: .init(x: 210, y: 20), color: .init(red: 112 / 255.0, green: 66 / 255.0, blue: 100 / 255.0, alpha: 0.6))
        img.drawLine(from: .init(x: 10, y: 21), to: .init(x: 210, y: 21), color: .init(red: 112 / 255.0, green: 66 / 255.0, blue: 100 / 255.0, alpha: 0.6))
        img.drawLine(from: .init(x: 10, y: 22), to: .init(x: 210, y: 22), color: .init(red: 112 / 255.0, green: 66 / 255.0, blue: 100 / 255.0, alpha: 0.6))

        img.drawLine(from: .init(x: 10, y: 35), to: .init(x: 210, y: 35), color: .init(red: 33 / 255.0, green: 61 / 255.0, blue: 139 / 255.0, alpha: 0.6))
        img.drawLine(from: .init(x: 10, y: 36), to: .init(x: 210, y: 36), color: .init(red: 33 / 255.0, green: 61 / 255.0, blue: 139 / 255.0, alpha: 0.6))
        img.drawLine(from: .init(x: 10, y: 37), to: .init(x: 210, y: 37), color: .init(red: 33 / 255.0, green: 61 / 255.0, blue: 139 / 255.0, alpha: 0.6))
        
        // Render dots.
        for _ in 1...25 {
            let x = Int.random(in: 9...210)
            let y = Int.random(in: 4...55)
            let size = Int.random(in: 2...4)

            img.fillEllipse(center: Point(x: x, y: y),
                            size: Size(width: size, height: size),
                            color: self.colors.randomElement() ?? .black)
        }
        
        // Export as JPG data.
        let imageData = try img.export(as: .jpg(quality: 90))
        return imageData
    }
    
    private func createRandomText(length: Int) -> String {
        // Only letters that are easy to guess (without IO0 etc.).
        let letters = "abdefghijkmnpqrtuvwyzABDEFGHJKLMNPQRSTUVWXYZ123456789"
        return String((0 ... (length - 1)).map { _ in letters.randomElement()! })
    }
}
