//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import SwiftGD

extension ArticlesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("articles")
    
    func boot(routes: RoutesBuilder) throws {
        let articlesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(ArticlesController.uri)
            .grouped(UserAuthenticator())
        
        articlesGroup
            .grouped(EventHandlerMiddleware(.articlesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        articlesGroup
            .grouped(EventHandlerMiddleware(.articlesRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":id", use: read)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesFileUpload))
            .grouped(CacheControlMiddleware(.noStore))
            .on(.POST, ":id", "file", body: .collect(maxSize: "20mb"), use: fileUpload)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesFileDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", "file", ":fileId", use: fileDelete)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesMainFile))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "file", ":fileId", "main", use: mainFile)
        
        articlesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.articlesDismiss))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "dismiss", use: dismiss)
    }
}

/// Exposing list of articles.
///
/// Endpoint is returning list of articles added to the system. In different part of the system we can display articles.
///
/// > Important: Base controller URL: `/api/v1/articles`.
struct ArticlesController {
    
    private struct FileRequest: Content {
        var file: File
    }
    
    /// Exposing list of articles.
    ///
    /// The endpoint returns list of articles with paginable functionality.
    /// For signend out user the list displayed only public articles.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `visibility` - one of all available enums: `signOutHome`, `signInHome`, `news`.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles?visibility=signOutHome" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "id": "7302167186067544065",
    ///             "title": "New abstract title",
    ///             "body": "This is some article",
    ///             "visibilities": ["signInHome", "signInNews"],
    ///             "user": { ... }
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 2,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable categories.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<ArticleDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let visibility: ArticleVisibilityDto? = request.query["visibility"]
        let dismissed: Bool = request.query["dismissed"] ?? false
                
        let articlesService = request.application.services.articlesService
        
        if request.isAdministrator == false && request.isModerator == false {
            let allowedVisibilities = articlesService.allowedVisibilities(on: request)
            if allowedVisibilities.contains(where: { $0 == visibility }) == false {
                throw Abort(request.userId == nil ? .unauthorized : .forbidden)
            }
        }
                
        var query = Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
        
        if let visibility {
            query = query
                .join(ArticleVisibility.self, on: \ArticleVisibility.$article.$id == \Article.$id)
                .filter(ArticleVisibility.self, \.$articleVisibilityType == visibility.translate())
        }
        
        if dismissed == false, let authorizationPayloadId = request.userId  {
            query = query
                .join(ArticleRead.self, on: \ArticleRead.$article.$id == \Article.$id && \ArticleRead.$user.$id == authorizationPayloadId, method: .left)
                .filter(ArticleRead.self, \.$createdAt == nil)
        }
        
        let articlesFromDatabase = try await query
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
                
        let articlesDtos = articlesFromDatabase.items.map { articlesService.convertToDto(article: $0, on: request.executionContext) }
        return PaginableResultDto(
            data: articlesDtos,
            page: articlesFromDatabase.metadata.page,
            size: articlesFromDatabase.metadata.per,
            total: articlesFromDatabase.metadata.total
        )
    }
    
    /// Get existing article.
    ///
    /// The endpoint can be used for downloading existing article from the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7302167186067544065" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "title": "New abstract title",
    ///     "body": "This is some article",
    ///     "visibilities": ["signInHome", "signInNews"],
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Entity data.
    ///
    /// - Throws: `ArticleError.incorrectArticleId` if article id is incorrect.
    /// - Throws: `EntityNotFoundError.articleNotFound` if article not found.
    @Sendable
    func read(request: Request) async throws -> ArticleDto {
        guard let articleIdString = request.parameters.get("id", as: String.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleId = articleIdString.toId() else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleFromDatabase = try await Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
            .filter(\.$id == articleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        let articlesService = request.application.services.articlesService
        if articlesService.isAuthorized(article: articleFromDatabase, on: request) == false {
            throw Abort(request.userId == nil ? .unauthorized : .forbidden)
        }
                
        return articlesService.convertToDto(article: articleFromDatabase, on: request.executionContext)
    }
    
    /// Create new article.
    ///
    /// The endpoint can be used for creating new article in the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "title": "Abstract title",
    ///     "body": "This is some article",
    ///     "visibilities": ["signInHome", "signInNews"]
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "title": "Abstract title",
    ///     "body": "This is some article",
    ///     "visibilities": ["signInHome", "signInNews"],
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        let authorizationPayloadId = try request.requireUserId()
        let articleDto = try request.content.decode(ArticleDto.self)
        try ArticleDto.validate(content: request)
        
        let newArticleId = request.application.services.snowflakeService.generate()
        let article = Article(id: newArticleId,
                              userId: authorizationPayloadId,
                              title: articleDto.title,
                              body: articleDto.body,
                              color: articleDto.color,
                              alternativeAuthor: articleDto.alternativeAuthor)

        var articleVisibilities: [ArticleVisibility] = []
        
        for visibility in articleDto.visibilities {
            let newArticleVisiblityId = request.application.services.snowflakeService.generate()
            let newArticleVisibility = ArticleVisibility(id: newArticleVisiblityId,
                                                         articleId: newArticleId,
                                                         articleVisibilityType: visibility.translate())
            
            articleVisibilities.append(newArticleVisibility)
        }
        
        let articleVisibilitiesToSave = articleVisibilities
        try await request.db.transaction { database in
            try await article.save(on: database)
            
            for articleVisibility in articleVisibilitiesToSave {
                try await articleVisibility.save(on: database)
            }
        }
        
        guard let articleFromDatabase = try await Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
            .filter(\.$id == newArticleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
                
        return try await createArticleResponse(on: request, article: articleFromDatabase)
    }
    
    /// Update existing article.
    ///
    /// The endpoint can be used for updating existing article in the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7302167186067544065" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "title": "New abstract title",
    ///     "body": "This is some article",
    ///     "visibilities": ["signInHome", "signInNews"]
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "title": "New abstract title",
    ///     "body": "This is some article",
    ///     "visibilities": ["signInHome", "signInNews"],
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    ///
    /// - Throws: `ArticleError.incorrectArticleId` if article id is incorrect.
    /// - Throws: `EntityNotFoundError.articleNotFound` if article not found.
    @Sendable
    func update(request: Request) async throws -> ArticleDto {
        let articleDto = try request.content.decode(ArticleDto.self)
        try ArticleDto.validate(content: request)
        
        guard let articleIdString = request.parameters.get("id", as: String.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleId = articleIdString.toId() else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleFromDatabase = try await Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
            .filter(\.$id == articleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        articleFromDatabase.title = articleDto.title
        articleFromDatabase.body = articleDto.body
        articleFromDatabase.color = articleDto.color
        articleFromDatabase.alternativeAuthor = articleDto.alternativeAuthor
        
        var visibilitiesToAdd: [ArticleVisibility] = []
        var visibilitiesToDelete: [ArticleVisibility] = []

        // Calculate article visibilities to add.
        for visibility in articleDto.visibilities {
            let visibilityFromDatabase = articleFromDatabase.articleVisibilities.first(where: { $0.articleVisibilityType == visibility.translate() })
            if visibilityFromDatabase == nil {
                let newArticleVisibilityId = request.application.services.snowflakeService.generate()
                let newArticleVisibility = try ArticleVisibility(id: newArticleVisibilityId,
                                                                 articleId: articleFromDatabase.requireID(),
                                                                 articleVisibilityType: visibility.translate())
                
                visibilitiesToAdd.append(newArticleVisibility)
            }
        }
        
        // Calculate article visibility to delete.
        for articleVisibilityFromDatabase in articleFromDatabase.articleVisibilities {
            let visibilityFromDto = articleDto.visibilities.first(where: { $0 == ArticleVisibilityDto.from(articleVisibilityFromDatabase.articleVisibilityType) })
            if visibilityFromDto == nil {
                visibilitiesToDelete.append(articleVisibilityFromDatabase)
            }
        }
                
        let visibilitiesToDatabaseAdd = visibilitiesToAdd
        let visibilitiesToDatabaseDelete = visibilitiesToDelete

        // Save everything to database in one transaction.
        try await request.db.transaction { database in
            try await articleFromDatabase.save(on: database)

            for visibility in visibilitiesToDatabaseAdd {
                try await visibility.create(on: database)
            }
            
            for visibility in visibilitiesToDatabaseDelete {
                try await visibility.delete(on: database)
            }
        }
        
        guard let articleFromDatabase = try await Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
            .filter(\.$id == articleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        let articlesService = request.application.services.articlesService
        return articlesService.convertToDto(article: articleFromDatabase, on: request.executionContext)
    }
    
    /// Delete article from the database.
    ///
    /// The endpoint can be used for deleting existing articles.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7267938074834522113" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    ///
    /// - Throws: `ArticleError.incorrectArticleId` if article id is incorrect.
    /// - Throws: `EntityNotFoundError.articleNotFound` if article not found.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let articleIdString = request.parameters.get("id", as: String.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleId = articleIdString.toId() else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleFromDatabase = try await Article.query(on: request.db)
            .with(\.$user)
            .with(\.$articleVisibilities)
            .with(\.$mainArticleFileInfo)
            .with(\.$articleFileInfos)
            .filter(\.$id == articleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
                
        // Datelete article and his visibilities from database in one transaction.
        try await request.db.transaction { database in
            articleFromDatabase.$mainArticleFileInfo.id = nil
            try await articleFromDatabase.save(on: database)

            for articleFileInfo in articleFromDatabase.articleFileInfos {
                try await articleFileInfo.delete(on: database)
            }
            
            for articleVisibility in articleFromDatabase.articleVisibilities {
                try await articleVisibility.delete(on: database)
            }
            
            try await articleFromDatabase.delete(on: database)
        }
        
        return HTTPStatus.ok
    }
    
    /// Uploading file to the article.
    ///
    /// The endpoint is used to uploading the files which can be added to the article.
    /// Only jpg and png files are supported.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id/file`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7267938074834522113/file" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -F 'file=@"/data/draw.jpg"'
    /// ```
    ///
    /// **Example request header:**
    ///
    /// ```
    /// Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryozM7tKuqLq2psuEB
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB
    /// Content-Disposition: form-data; name="file"; filename="draw.jpg"
    /// Content-Type: image/jpg
    ///
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB--
    /// [BINARY_DATA]
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333518540363030529",
    ///     "url": "https://example.com/articles/7267938074834522113/ghnr9tjdnbrw.jpg"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about uploaded file.
    ///
    /// - Throws: `ArticleError.missingFile` if missing file.
    /// - Throws: `ArticleError.incorrectArticleId` incorrect article id.
    /// - Throws: `EntityNotFoundError.articleNotFound` article not found.
    /// - Throws: `ArticleError.fileTypeNotSupported` file type is not supported.
    /// - Throws: `ArticleError.imageTooLarge` image is too large.
    @Sendable
    func fileUpload(request: Request) async throws -> ArticleFileInfoDto {
        guard let articleIdString = request.parameters.get("id", as: String.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleId = articleIdString.toId() else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let article = try await Article.query(on: request.db)
            .filter(\.$id == articleId)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        guard let fileRequest = try? request.content.decode(FileRequest.self) else {
            throw ArticleError.missingFile
        }

        guard fileRequest.file.data.readableBytes < Constants.imageSizeLimit else {
            throw ArticleError.imageTooLarge
        }
        
        // Create image in the memory.
        let fileName = fileRequest.file.filename
        guard let image = Image.create(fileName: fileName, byteBuffer: fileRequest.file.data) else {
            throw ArticleError.fileTypeNotSupported
        }
        
        // Prepare file path (always in correct articles folder).
        let fileUri = "/articles/\(articleIdString)/\(fileRequest.file.filename)"

        // Save file into the storage.
        let storageService = request.application.services.storageService
        let filePath = try await storageService.save(fileName: fileUri, byteBuffer: fileRequest.file.data, on: request.executionContext)
        
        let newArticleFileInfoId = request.application.services.snowflakeService.generate()
        let onlyFileName = filePath.pathComponents.last?.description ?? filePath
        
        let articleFileInfo = ArticleFileInfo(id: newArticleFileInfoId,
                                              articleId: articleId,
                                              fileName: onlyFileName,
                                              width: image.size.width,
                                              height: image.size.height)

        try await articleFileInfo.save(on: request.db)
        
        let baseImagesPath = storageService.getBaseImagesPath(on: request.executionContext)
        return ArticleFileInfoDto(id: articleFileInfo.stringId() ?? "",
                                  url: "\(baseImagesPath.finished(with: "/"))articles/\(article.stringId() ?? "")/\(articleFileInfo.fileName)",
                                  width: articleFileInfo.width,
                                  height: articleFileInfo.height)
    }
        
    /// Delete article file.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id/file/:fileId`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7267938074834522113/file/7333518540363030529" \
    /// -X DELETE \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.articleNotFound` article not found.
    /// - Throws: `ArticleError.incorrectArticleId` incorrect article id.
    /// - Throws: `ArticleError.incorrectArticleFileId` incorrect article file id.
    /// - Throws: `EntityNotFoundError.articleFileInfoNotFound` article not found.
    /// - Throws: `ArticleError.fileConnectedWithDifferentArticle` file is connected to different article.
    @Sendable
    func fileDelete(request: Request) async throws -> HTTPStatus {
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let fileId = request.parameters.get("fileId", as: Int64.self) else {
            throw ArticleError.incorrectArticleFileId
        }
                
        guard let article = try await Article.query(on: request.db)
            .filter(\.$id == id)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        guard let articleFileInfo = try await ArticleFileInfo.query(on: request.db)
            .filter(\.$id == fileId)
            .first() else {
            throw EntityNotFoundError.articleFileInfoNotFound
        }
        
        guard articleFileInfo.$article.id == article.id else {
            throw ArticleError.fileConnectedWithDifferentArticle
        }
        
        try await request.db.transaction { database in
            if article.$mainArticleFileInfo.id == articleFileInfo.id {
                article.$mainArticleFileInfo.id = nil
                try await article.save(on: database)
            }
            
            try await articleFileInfo.delete(on: database)
        }
        
        let storageService = request.application.services.storageService
        let fileUri = "/articles/\(article.stringId() ?? "")/\(articleFileInfo.fileName)"

        request.logger.info("Delete file from storage: \(fileUri).")
        try await storageService.delete(fileName: fileUri, on: request.executionContext)
        
        return HTTPStatus.ok
    }

    /// Mark article file as a main article file.
    ///
    /// These file will be returned as a main article image (in Open Graph for example).
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id/file/:fileId/main`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7267938074834522113/file/7333518540363030529/main" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.articleNotFound` article not found.
    /// - Throws: `EntityNotFoundError.articleFileInfoNotFound` article not found.
    /// - Throws: `ArticleError.fileConnectedWithDifferentArticle` file is connected to different article.
    /// - Throws: `ArticleError.incorrectArticleId` incorrect article id.
    /// - Throws: `ArticleError.incorrectArticleFileId` incorrect article file id.
    @Sendable
    func mainFile(request: Request) async throws -> HTTPStatus {
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let fileId = request.parameters.get("fileId", as: Int64.self) else {
            throw ArticleError.incorrectArticleFileId
        }
                
        guard let article = try await Article.query(on: request.db)
            .filter(\.$id == id)
            .first() else {
            throw EntityNotFoundError.articleNotFound
        }
        
        guard let articleFileInfo = try await ArticleFileInfo.query(on: request.db)
            .filter(\.$id == fileId)
            .first() else {
            throw EntityNotFoundError.articleFileInfoNotFound
        }
        
        guard articleFileInfo.$article.id == article.id else {
            throw ArticleError.fileConnectedWithDifferentArticle
        }

        article.$mainArticleFileInfo.id = articleFileInfo.id
        try await article.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Mark article ad read.
    ///
    /// The endpoint can be used for marking that specific article has been read by the user.
    ///
    /// > Important: Endpoint URL: `/api/v1/articles/:id/dismiss`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/articles/7302167186067544065/dismiss" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `ArticleError.incorrectArticleId` incorrect article id.
    /// - Throws: `ArticleError.incorrectArticleFileId` incorrect article file id.
    @Sendable
    func dismiss(request: Request) async throws -> HTTPStatus {
        let authorizationPayloadId = try request.requireUserId()

        guard let articleIdString = request.parameters.get("id", as: String.self) else {
            throw ArticleError.incorrectArticleId
        }
        
        guard let articleId = articleIdString.toId() else {
            throw ArticleError.incorrectArticleId
        }
        
        guard try await ArticleRead.query(on: request.db)
            .filter(\.$article.$id == articleId)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() == nil else {
            return HTTPStatus.ok
        }
        
        let newArticleReadId = request.application.services.snowflakeService.generate()
        let newArticleRead = ArticleRead(id: newArticleReadId, userId: authorizationPayloadId, articleId: articleId)
        try await newArticleRead.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    private func createArticleResponse(on request: Request, article: Article) async throws -> Response {
        let articlesService = request.application.services.articlesService
        let articleDto = articlesService.convertToDto(article: article, on: request.executionContext)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(ArticlesController.uri)/\(article.stringId() ?? "")")
        
        return try await articleDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
