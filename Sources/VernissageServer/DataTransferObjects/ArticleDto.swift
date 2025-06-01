//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ArticleDto {
    var id: String?
    var title: String?
    var body: String
    var bodyHtml: String?
    var color: String?
    var alternativeAuthor: String?
    let user: UserDto?
    let mainArticleFileInfo: ArticleFileInfoDto?
    var createdAt: Date?
    var updatedAt: Date?
    var visibilities: [ArticleVisibilityDto]
}

extension ArticleDto {
    init(from article: Article, bodyHtml: String, baseAddress: String, baseImagesPath: String) {
        let mainArticleFileInfo: ArticleFileInfoDto? = if let mainArticleFileInfo = article.mainArticleFileInfo {
            ArticleFileInfoDto(url: "\(baseImagesPath.finished(with: "/"))articles/\(article.stringId() ?? "")/\(mainArticleFileInfo.fileName)",
                               width: mainArticleFileInfo.width,
                               height: mainArticleFileInfo.height)
        } else {
            nil
        }
        
        self.init(id: article.stringId(),
                  title: article.title,
                  body: article.body,
                  bodyHtml: bodyHtml,
                  color: article.color,
                  alternativeAuthor: article.alternativeAuthor,
                  user: UserDto(from: article.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  mainArticleFileInfo: mainArticleFileInfo,
                  createdAt: article.createdAt,
                  updatedAt: article.updatedAt,
                  visibilities: article.articleVisibilities.map { ArticleVisibilityDto.from($0.articleVisibilityType) })
    }
}

extension ArticleDto: Content { }

extension ArticleDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String?.self, is: .count(...200) || .nil, required: false)
        validations.add("body", as: String.self, is: .count(1...50000), required: true)
        validations.add("color", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("alternativeAuthor", as: String?.self, is: .count(...500) || .nil, required: false)
    }
}
