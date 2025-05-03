//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createArticleFileInfo(articleId: Int64, fileName: String, width: Int, heigth: Int) async throws -> ArticleFileInfo {
        let id = await ApplicationManager.shared.generateId()
        let articleFileInfo = ArticleFileInfo(id: id, articleId: articleId, fileName: fileName, width: width, height: heigth)
        try await articleFileInfo.save(on: self.db)

        return articleFileInfo
    }
}
