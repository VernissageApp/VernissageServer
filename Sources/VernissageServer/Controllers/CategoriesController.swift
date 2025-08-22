//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension CategoriesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("categories")
    
    func boot(routes: RoutesBuilder) throws {
        let categoriesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(CategoriesController.uri)
            .grouped(UserAuthenticator())
        
        categoriesGroup
            .grouped(EventHandlerMiddleware(.categoriesList))
            .grouped(CacheControlMiddleware(.public()))
            .get("all", use: all)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesEnable))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "enable", use: enable)
        
        categoriesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.categoriesDisable))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "disable", use: disable)
    }
}

/// Exposing list of categories.
///
/// Each status can be assigned to at most one category. This controller is used to manage categories in the system.
/// Also, statuses downloaded through ActivityPub are automatically assigned to categories by mapping hashtags to categories.
///
/// > Important: Base controller URL: `/api/v1/categories`.
struct CategoriesController {
    
    /// Exposing list of categories.
    ///
    /// The endpoint returns list of categories with paginable functionality.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/categories`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories" \
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
    ///             "name": "Abstract",
    ///                 "hashtags: [
    ///                     {
    ///                         "id": "7302167186067544066",
    ///                         "hashtag": "abstract",
    ///                         "hashtagNormalized": "ABSTRACT"
    ///                     }
    ///                 ]
    ///         }, {
    ///             "id": "7302167186067558401",
    ///             "name": "Aerial"
    ///         }, {
    ///             "id": "7302167186067845121",
    ///             "name": "Transportation"
    ///         }, {
    ///             "id": "7302167186067859457",
    ///             "name": "Travel"
    ///         }, {
    ///             "id": "7302167186067873793",
    ///             "name": "Wedding"
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
    func list(request: Request) async throws -> PaginableResultDto<CategoryDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let categoriesFromDatabase = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .sort(\.$name, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let categoriesDtos = categoriesFromDatabase.items.map { CategoryDto(from: $0, with: $0.hashtags) }

        return PaginableResultDto(
            data: categoriesDtos,
            page: categoriesFromDatabase.metadata.page,
            size: categoriesFromDatabase.metadata.per,
            total: categoriesFromDatabase.metadata.total
        )
    }
    
    /// Exposing list of categories (only enabled categories).
    ///
    /// The endpoint returns a list of all categories that are added to the system.
    /// Result can be stored by the browser (for one hour).
    ///
    /// Optional query params:
    /// - `onlyUsed` - `true` if list should contain only categories which has been used
    ///
    /// > Important: Endpoint URL: `/api/v1/categories/all`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories/all" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "id": "7302167186067544065",
    ///     "name": "Abstract",
    ///     "hashtags: [
    ///         {
    ///             "id": "7302167186067544066",
    ///             "hashtag": "abstract",
    ///             "hashtagNormalized": "ABSTRACT"
    ///         }
    ///    ]
    /// }, {
    ///     "id": "7302167186067558401",
    ///     "name": "Aerial"
    /// }, {
    ///     "id": "7302167186067845121",
    ///     "name": "Transportation"
    /// }, {
    ///     "id": "7302167186067859457",
    ///     "name": "Travel"
    /// }, {
    ///     "id": "7302167186067873793",
    ///     "name": "Wedding"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of categories.
    @Sendable
    func all(request: Request) async throws -> [CategoryDto] {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showCategoriesForAnonymous == false {
            throw ActionsForbiddenError.categoriesForbidden
        }
        
        let onlyUsed: Bool = request.query["onlyUsed"] ?? false
        
        let categories = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$isEnabled == true)
            .sort(\.$name, .ascending)
            .all()
        
        if onlyUsed {
            var usedCategories: [Category] = []

            try await categories.asyncForEach { category in
                if let _ = try await Status.query(on: request.db)
                    .filter(\.$category.$id == category.requireID())
                    .first() {
                    usedCategories.append(category)
                }
            }
            
            return usedCategories.map({ CategoryDto(from: $0, with: $0.hashtags) })
        }
        
        return categories.map({ CategoryDto(from: $0, with: $0.hashtags) })
    }
    
    /// Create new category.
    ///
    /// The endpoint can be used for creating new category in the system (with hashtags).
    ///
    /// > Important: Endpoint URL: `/api/v1/categories`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories" \
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
    ///     "name": "Abstract",
    ///     "hashtags: [
    ///         {
    ///             "hashtag": "abstract",
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "name": "Abstract",
    ///     "hashtags: [
    ///         {
    ///             "id": "7302167186067544066",
    ///             "hashtag": "abstract",
    ///             "hashtagNormalized": "ABSTRACT"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        let categoryDto = try request.content.decode(CategoryDto.self)
        try CategoryDto.validate(content: request)
        
        let categoryFromDatabase = try await Category.query(on: request.db)
            .filter(\.$name == categoryDto.name)
            .first()
        
        guard categoryFromDatabase == nil else {
            throw CategoryError.categoryExists
        }
        
        let newCategoryId = request.application.services.snowflakeService.generate()
        let category = Category(id: newCategoryId, name: categoryDto.name, priority: categoryDto.priority ?? 0)
        var hashtags: [CategoryHashtag] = []
        
        if let hashtagDtos = categoryDto.hashtags {
            for hashtagDto in hashtagDtos {
                let newHashtagId = request.application.services.snowflakeService.generate()
                hashtags.append(CategoryHashtag(id: newHashtagId, categoryId: newCategoryId, hashtag: hashtagDto.hashtag))
            }
        }
        
        let hashtagsToSave = hashtags
        try await request.db.transaction { database in
            try await category.save(on: database)
            for hashtag in hashtagsToSave {
                try await hashtag.save(on: database)
            }
        }
        
        return try await createCategoryResponse(on: request, category: category, categoryHashtags: hashtagsToSave)
    }
    
    /// Update existing category.
    ///
    /// The endpoint can be used for updating existing category in the system (with hashtags).
    ///
    /// > Important: Endpoint URL: `/api/v1/categories/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories/7302167186067544065" \
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
    ///     "name": "Abstract",
    ///     "hashtags: [
    ///         {
    ///             "hashtag": "abstract",
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7302167186067544065",
    ///     "name": "Abstract",
    ///     "hashtags: [
    ///         {
    ///             "id": "7302167186067544066",
    ///             "hashtag": "abstract",
    ///             "hashtagNormalized": "ABSTRACT"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func update(request: Request) async throws -> CategoryDto {
        let categoryDto = try request.content.decode(CategoryDto.self)
        try CategoryDto.validate(content: request)
        
        guard let categoryIdString = request.parameters.get("id", as: String.self) else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryId = categoryIdString.toId() else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryFromDatabase = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$id == categoryId)
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        categoryFromDatabase.name = categoryDto.name
        categoryFromDatabase.priority = categoryDto.priority ?? 0
        categoryFromDatabase.isEnabled = categoryDto.isEnabled ?? true
        categoryFromDatabase.nameNormalized = categoryDto.name.uppercased()
        
        var hashtagsToAdd: [CategoryHashtag] = []
        var hashtagsToUpdate: [CategoryHashtag] = []
        var hashtagsToDelete: [CategoryHashtag] = []

        // Calculate hashtags to add or update.
        for hashtagDto in categoryDto.hashtags ?? [] {
            let hashtagFromDatabase = categoryFromDatabase.hashtags.first(where: { $0.stringId() == hashtagDto.id })
            if let hashtagFromDatabase {
                hashtagFromDatabase.hashtag = hashtagDto.hashtag
                hashtagFromDatabase.hashtagNormalized = hashtagDto.hashtag.uppercased()
                hashtagsToUpdate.append(hashtagFromDatabase)
            } else {
                let newHashtagId = request.application.services.snowflakeService.generate()
                try hashtagsToAdd.append(CategoryHashtag(id: newHashtagId, categoryId: categoryFromDatabase.requireID(), hashtag: hashtagDto.hashtag))
            }
        }
        
        // Calculate hashtags to delete.
        for hashtagFromDatabase in categoryFromDatabase.hashtags {
            let hashtagFromDto = categoryDto.hashtags?.first(where: { $0.id == hashtagFromDatabase.stringId() })
            if hashtagFromDto == nil {
                hashtagsToDelete.append(hashtagFromDatabase)
            }
        }
                
        let hashtagsToDatabaseAdd = hashtagsToAdd
        let hashtagsToDatabaseUpdate = hashtagsToUpdate
        let hashtagsToDatabaseDelete = hashtagsToDelete

        // Save everything to database in one transaction.
        try await request.db.transaction { database in
            try await categoryFromDatabase.save(on: database)

            for hashtag in hashtagsToDatabaseAdd {
                try await hashtag.create(on: database)
            }
            
            for hashtag in hashtagsToDatabaseUpdate {
                try await hashtag.update(on: database)
            }
            
            for hashtag in hashtagsToDatabaseDelete {
                try await hashtag.delete(on: database)
            }
        }
        
        guard let categoryFromDatabaseAfterSave = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$id == categoryId)
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        return CategoryDto(from: categoryFromDatabaseAfterSave, with: categoryFromDatabaseAfterSave.hashtags)
    }
    
    /// Delete category from the database.
    ///
    /// The endpoint can be used for deleting existing categories.
    ///
    /// > Important: Endpoint URL: `/api/v1/categories/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories/7267938074834522113" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let categoryIdString = request.parameters.get("id", as: String.self) else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryId = categoryIdString.toId() else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryFromDatabase = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$id == categoryId)
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        let statusWithCategory = try await Status.query(on: request.db).filter(\.$category.$id == categoryId).first()
        guard statusWithCategory == nil else {
            throw CategoryError.categoryCannotBeDeletedBecauseItIsInUse
        }
        
        // Datelete category and hashtags from database in one transaction.
        try await request.db.transaction { database in
            for hashtag in categoryFromDatabase.hashtags {
                try await hashtag.delete(on: database)
            }
            
            try await categoryFromDatabase.delete(on: database)
        }
        
        return HTTPStatus.ok
    }
    
    /// Enable specific category.
    ///
    /// The endpoint can be used for enabling category (only enabled categories will be used to hashtag connection mechanism).
    ///
    /// > Important: Endpoint URL: `/api/v1/categories/:id/enable`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories/7267938074834522113/enable" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func enable(request: Request) async throws -> HTTPStatus {
        guard let categoryIdString = request.parameters.get("id", as: String.self) else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryId = categoryIdString.toId() else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryFromDatabase = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$id == categoryId)
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        categoryFromDatabase.isEnabled = true
        try await categoryFromDatabase.save(on: request.db)

        return HTTPStatus.ok
    }
    
    /// Disable specific category.
    ///
    /// The endpoint can be used for disabling category (only enabled categories will be used to hashtag connection mechanism).
    ///
    /// > Important: Endpoint URL: `/api/v1/categories/:id/disable`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories/7267938074834522113/disable" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func disable(request: Request) async throws -> HTTPStatus {
        guard let categoryIdString = request.parameters.get("id", as: String.self) else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryId = categoryIdString.toId() else {
            throw CategoryError.incorrectCategoryId
        }
        
        guard let categoryFromDatabase = try await Category.query(on: request.db)
            .with(\.$hashtags)
            .filter(\.$id == categoryId)
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        categoryFromDatabase.isEnabled = false
        try await categoryFromDatabase.save(on: request.db)

        return HTTPStatus.ok
    }
    
    private func createCategoryResponse(on request: Request, category: Category, categoryHashtags: [CategoryHashtag]) async throws -> Response {
        let categoryDto = CategoryDto(from: category, with: categoryHashtags)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(CategoriesController.uri)/@\(category.stringId() ?? "")")
        
        return try await categoryDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
