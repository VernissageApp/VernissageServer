//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension SharedBusinessCardsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("shared-business-cards")
    
    func boot(routes: RoutesBuilder) throws {
        let sharedBusinessCardsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SharedBusinessCardsController.uri)
            .grouped(UserAuthenticator())
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":id", use: read)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardMessage))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "message", use: message)
        
        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardRevoke))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "revoke", use: revoke)

        sharedBusinessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.sharedBusinessCardUnrevoke))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "unrevoke", use: unrevoke)
        
        sharedBusinessCardsGroup
            .grouped(EventHandlerMiddleware(.sharedBusinessCardReadByThirdParty))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":id", "third-party", use: readByThirdParty)
                
        sharedBusinessCardsGroup
            .grouped(EventHandlerMiddleware(.sharedBusinessCardUpdateByThirdParty))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", "third-party", use: updateByThirdParty)
        
        sharedBusinessCardsGroup
            .grouped(EventHandlerMiddleware(.sharedBusinessCardMessageByThirdParty))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "third-party", "message", use: messageByThirdParty)
    }
}

/// Exposing shared business card logic.
///
/// Endpoint is responsible for all business logic regarding shared business cards.
///
/// > Important: Base controller URL: `/api/v1/shared-business-cards`.
struct SharedBusinessCardsController {
    
    /// Exposing list of shared business cards.
    ///
    /// The endpoint returns list of shared business cards with paginable functionality.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards" \
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
    ///             "code": "9nBFMtpvUm6vBcQCUQLNsIVoy7WtPxwRxqb5UTw3oseWIuIu6yeBbM53qE1dR7xh",
    ///             "createdAt": "2025-04-28T19:15:55.240Z",
    ///             "id": "7498444910865942753",
    ///             "note": "Photos taken near the bridge",
    ///             "revokedAt": "2025-04-28T19:16:54.140Z",
    ///             "thirdPartyEmail": "johmdoe@example.com",
    ///             "thirdPartyName": "Marcin111",
    ///             "title": "The bridge portraits",
    ///             "updatedAt": "2025-04-28T19:16:54.141Z"
    ///         },
    ///         {
    ///             "code": "fWP0kDKZCA7x8SRmBgaqlK6g51ulprP2zhQ97DhuFwpsjYqrLShnPtweMtZ6gKe7",
    ///             "createdAt": "2025-04-28T11:49:40.000Z",
    ///             "id": "7498329908821625471",
    ///             "note": "Two ladies with dog near the cathedral",
    ///             "revokedAt": "2025-04-28T19:16:54.504Z",
    ///             "thirdPartyEmail": "anna.doe@example.com",
    ///             "thirdPartyName": "Anna Maria Jopek",
    ///             "title": "Cathedar ladies",
    ///             "updatedAt": "2025-04-28T19:16:54.504Z"
    ///          }
    ///     ],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 2
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable shared business cards.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<SharedBusinessCardDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10

        let sharedBusinessCardsFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))

        let businessCardsService = request.application.services.businessCardsService
        let sharedBusinessCardsDtos = sharedBusinessCardsFromDatabase.items.map {
            businessCardsService.convertToDto(sharedBusinessCard: $0, messages: nil, on: request.executionContext)
        }

        return PaginableResultDto(
            data: sharedBusinessCardsDtos,
            page: sharedBusinessCardsFromDatabase.metadata.page,
            size: sharedBusinessCardsFromDatabase.metadata.per,
            total: sharedBusinessCardsFromDatabase.metadata.total
        )
    }
    
    /// Get existing shared business card.
    ///
    /// The endpoint can be used for downloading existing shared business card from the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7302167186067544065" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "9nBFMtpvUm6vBcQCUQLNsIVoy7WtPxwRxqb5UTw3oseWIuIu6yeBbM53qE1dR7xh",
    ///     "createdAt": "2025-04-28T19:15:55.240Z",
    ///     "id": "7498444910865942753",
    ///     "messages": [
    ///         {
    ///             "addedByUser": false,
    ///             "createdAt": "2025-04-28T19:16:28.075Z",
    ///             "id": "7498445052599863521",
    ///             "message": "Ala ma kota",
    ///             "updatedAt": "2025-04-28T19:16:28.075Z"
    ///         },
    ///         {
    ///             "addedByUser": true,
    ///             "createdAt": "2025-04-28T19:16:36.168Z",
    ///             "id": "7498445086959601889",
    ///             "message": "Ale",
    ///             "updatedAt": "2025-04-28T19:16:36.168Z"
    ///         }
    ///     ],
    ///     "note": "This is note for card",
    ///     "revokedAt": "2025-04-28T19:16:54.140Z",
    ///     "thirdPartyEmail": "jdoe@example.com",
    ///     "thirdPartyName": "Joanna Doe",
    ///     "title": "The title",
    ///     "updatedAt": "2025-04-28T19:16:54.141Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Entity data.
    @Sendable
    func read(request: Request) async throws -> SharedBusinessCardDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        let businessCardsService = request.application.services.businessCardsService
        return businessCardsService.convertToDto(sharedBusinessCard: sharedBusinessCardFromDatabase,
                                                 messages: sharedBusinessCardFromDatabase.messages,
                                                 on: request.executionContext)
    }
    
    /// Create new shared business card.
    ///
    /// The endpoint can be used for creating new shared business card in the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards" \
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
    ///     "title": "The title",
    ///     "note": "This is note for card",
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "9nBFMtpvUm6vBcQCUQLNsIVoy7WtPxwRxqb5UTw3oseWIuIu6yeBbM53qE1dR7xh",
    ///     "createdAt": "2025-04-28T19:15:55.240Z",
    ///     "id": "7498444910865942753",
    ///     "note": "This is note for card",
    ///     "thirdPartyEmail": "",
    ///     "thirdPartyName": "",
    ///     "title": "The title",
    ///     "updatedAt": "2025-04-28T19:16:54.141Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let sharedBusinessCardDto = try request.content.decode(SharedBusinessCardDto.self)
        try SharedBusinessCardDto.validate(content: request)
                        
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }
        
        let newSharedBusinessCardId = request.application.services.snowflakeService.generate()
        let code = String.createRandomString(length: 64)
        
        let sharedBusinessCard = try SharedBusinessCard(id: newSharedBusinessCardId,
                                                        businessCardId: businessCardFromDatabase.requireID(),
                                                        code: code,
                                                        title: sharedBusinessCardDto.title,
                                                        note: sharedBusinessCardDto.note,
                                                        thirdPartyName: sharedBusinessCardDto.thirdPartyName ?? "",
                                                        thirdPartyEmail: sharedBusinessCardDto.thirdPartyEmail)
        
        try await sharedBusinessCard.save(on: request.db)
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .filter(\.$id == newSharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        return try await createSharedBusinessCardResponse(on: request, sharedBusinessCard: sharedBusinessCardFromDatabase)
    }
    
    /// Update existing shared business card.
    ///
    /// The endpoint can be used for updating existing shared business card in the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7302167186067544065" \
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
    ///     "id": "7498444910865942753",
    ///     "title": "New abstract title",
    ///     "note": "This is note for card"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "9nBFMtpvUm6vBcQCUQLNsIVoy7WtPxwRxqb5UTw3oseWIuIu6yeBbM53qE1dR7xh",
    ///     "createdAt": "2025-04-28T19:15:55.240Z",
    ///     "id": "7498444910865942753",
    ///     "note": "This is note for card",
    ///     "thirdPartyEmail": "",
    ///     "thirdPartyName": "",
    ///     "title": "New abstract title",
    ///     "updatedAt": "2025-04-28T19:16:54.141Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    @Sendable
    func update(request: Request) async throws -> SharedBusinessCardDto {
        let sharedBusinessCardDto = try request.content.decode(SharedBusinessCardDto.self)
        try SharedBusinessCardDto.validate(content: request)
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        sharedBusinessCardFromDatabase.title = sharedBusinessCardDto.title
        sharedBusinessCardFromDatabase.note = sharedBusinessCardDto.note
        sharedBusinessCardFromDatabase.thirdPartyName = sharedBusinessCardDto.thirdPartyName ?? ""
        sharedBusinessCardFromDatabase.thirdPartyEmail = sharedBusinessCardDto.thirdPartyEmail

        try await sharedBusinessCardFromDatabase.save(on: request.db)

        let businessCardsService = request.application.services.businessCardsService
        return businessCardsService.convertToDto(sharedBusinessCard: sharedBusinessCardFromDatabase,
                                                 messages: sharedBusinessCardFromDatabase.messages,
                                                 on: request.executionContext)
    }
    
    /// Delete shared business card from the database.
    ///
    /// The endpoint can be used for deleting existing shared business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7267938074834522113" \
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
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }

        // Datelete shared business card with all messages added to it.
        try await request.db.transaction { database in
            for message in sharedBusinessCardFromDatabase.messages {
                try await message.delete(on: database)
            }
            
            try await sharedBusinessCardFromDatabase.delete(on: database)
        }
        
        return HTTPStatus.ok
    }
    
    /// Add new message to shared business card by the owner.
    ///
    /// The endpoint can be used for adding new messages to the shared business card by his owner.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id/message`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7302167186067544065/message" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "message": "Hello. I'm your photographer!"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    @Sendable
    func message(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let sharedBusinessCardMessageDto = try request.content.decode(SharedBusinessCardMessageDto.self)
        try SharedBusinessCardMessageDto.validate(content: request)
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        let newSharedBusinessCardMessageId = request.application.services.snowflakeService.generate()
        let sharedBusinessCardMessage = try SharedBusinessCardMessage(id: newSharedBusinessCardMessageId,
                                                                      sharedBusinessCardId: sharedBusinessCardFromDatabase.requireID(),
                                                                      userId: authorizationPayloadId,
                                                                      message: sharedBusinessCardMessageDto.message)

        try await sharedBusinessCardMessage.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Revoke shared business card.
    ///
    /// The endpoint can be used for revoking access by third party to the shared business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id/revoke`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7302167186067544065/revoke" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    @Sendable
    func revoke(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        sharedBusinessCardFromDatabase.revokedAt = Date()
        try await sharedBusinessCardFromDatabase.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Unrevoke shared business card.
    ///
    /// The endpoint can be used for allowing access by third party to the shared business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:id/unrevoke`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/7302167186067544065/unrevoke" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    @Sendable
    func unrevoke(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let sharedBusinessCardIdString = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardId = sharedBusinessCardIdString.toId() else {
            throw SharedBusinessCardError.incorrectSharedBusinessCardId
        }
        
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .join(BusinessCard.self, on: \SharedBusinessCard.$businessCard.$id == \BusinessCard.$id)
            .filter(BusinessCard.self, \.$user.$id == authorizationPayloadId)
            .filter(\.$id == sharedBusinessCardId)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        sharedBusinessCardFromDatabase.revokedAt = nil
        try await sharedBusinessCardFromDatabase.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Get existing shared business card based on generated code.
    ///
    /// The endpoint can be used for downloading existing shared business card from the system.
    /// Shared business card is downloaded by code (by third party).
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:code/third-party`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/dfg8fg8aa6sdgt8bcxsdfas7tsafgh98gs8/third-party" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "9nBFMtpvUm6vBcQCUQLNsIVoy7WtPxwRxqb5UTw3oseWIuIu6yeBbM53qE1dR7xh",
    ///     "createdAt": "2025-04-28T19:15:55.240Z",
    ///     "id": "7498444910865942753",
    ///     "messages": [
    ///         {
    ///             "addedByUser": false,
    ///             "createdAt": "2025-04-28T19:16:28.075Z",
    ///             "id": "7498445052599863521",
    ///             "message": "Ala ma kota",
    ///             "updatedAt": "2025-04-28T19:16:28.075Z"
    ///         },
    ///         {
    ///             "addedByUser": true,
    ///             "createdAt": "2025-04-28T19:16:36.168Z",
    ///             "id": "7498445086959601889",
    ///             "message": "Ale",
    ///             "updatedAt": "2025-04-28T19:16:36.168Z"
    ///         }
    ///     ],
    ///     "note": "",
    ///     "revokedAt": "2025-04-28T19:16:54.140Z",
    ///     "thirdPartyEmail": "jdoe@example.com",
    ///     "thirdPartyName": "Joanna Doe",
    ///     "title": "",
    ///     "updatedAt": "2025-04-28T19:16:54.141Z"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Entity data.
    @Sendable
    func readByThirdParty(request: Request) async throws -> SharedBusinessCardDto {
        guard let sharedBusinessCardCode = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectCode
        }
                
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .filter(\.$code == sharedBusinessCardCode)
            .filter(\.$revokedAt == nil)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$id == sharedBusinessCardFromDatabase.$businessCard.id)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }
        
        let businessCardsService = request.application.services.businessCardsService
        return businessCardsService.convertToDto(sharedBusinessCard: sharedBusinessCardFromDatabase,
                                                 with: businessCardFromDatabase,
                                                 clearSensitive: true,
                                                 on: request.executionContext)
    }
    
    /// Update existing shared business card based on generated code.
    ///
    /// The endpoint can be used for updating existing shared business card in the system.
    /// Shared business card is updated by code (by third party).
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:code/third-party`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/dfg8fg8aa6sdgt8bcxsdfas7tsafgh98gs8/third-party" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "sharedCardUrl": "http://vernissage.com/codes/544grasgw454asdgf",
    ///     "thirdPartyEmail": "jdoe@example.com",
    ///     "thirdPartyName": "Joanna Doe"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func updateByThirdParty(request: Request) async throws -> HTTPStatus {
        let sharedBusinessCardUpdateRequestDto = try request.content.decode(SharedBusinessCardUpdateRequestDto.self)
        try SharedBusinessCardUpdateRequestDto.validate(content: request)

        guard let sharedBusinessCardCode = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectCode
        }
                
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .filter(\.$code == sharedBusinessCardCode)
            .filter(\.$revokedAt == nil)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        sharedBusinessCardFromDatabase.thirdPartyName = sharedBusinessCardUpdateRequestDto.thirdPartyName ?? ""
        sharedBusinessCardFromDatabase.thirdPartyEmail = sharedBusinessCardUpdateRequestDto.thirdPartyEmail
        
        try await sharedBusinessCardFromDatabase.update(on: request.db)
        
        // If email is specified we can send email with url to shared card.
        if sharedBusinessCardFromDatabase.thirdPartyEmail != nil && sharedBusinessCardFromDatabase.thirdPartyEmail?.isEmpty == false {
            let emailsService = request.application.services.emailsService
            try await emailsService.dispatchSharedBusinessCardEmail(sharedBusinessCard: sharedBusinessCardFromDatabase,
                                                                    sharedCardUrl: sharedBusinessCardUpdateRequestDto.sharedCardUrl,
                                                                    on: request.executionContext)
        }
        
        return HTTPStatus.ok
    }
    
    /// Add to shared business card message by third party. (code)
    ///
    /// The endpoint can be used for adding new message to the shared business card by third party.
    ///
    /// > Important: Endpoint URL: `/api/v1/shared-business-cards/:code/third-party/message`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/shared-business-cards/dfg8fg8aa6sdgt8bcxsdfas7tsafgh98gs8/third-party/message" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "message": "Hello. I'm your photographer!"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    @Sendable
    func messageByThirdParty(request: Request) async throws -> HTTPStatus {
        let sharedBusinessCardMessageDto = try request.content.decode(SharedBusinessCardMessageDto.self)
        try SharedBusinessCardMessageDto.validate(content: request)

        guard let sharedBusinessCardCode = request.parameters.get("id", as: String.self) else {
            throw SharedBusinessCardError.incorrectCode
        }
                
        guard let sharedBusinessCardFromDatabase = try await SharedBusinessCard.query(on: request.db)
            .with(\.$messages)
            .filter(\.$code == sharedBusinessCardCode)
            .filter(\.$revokedAt == nil)
            .first() else {
            throw EntityNotFoundError.sharedBusinessCardNotFound
        }
        
        let newSharedBusinessCardMessageId = request.application.services.snowflakeService.generate()
        let sharedBusinessCardMessage = try SharedBusinessCardMessage(id: newSharedBusinessCardMessageId,
                                      sharedBusinessCardId: sharedBusinessCardFromDatabase.requireID(),
                                      message: sharedBusinessCardMessageDto.message)
        
        try await sharedBusinessCardMessage.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    private func createSharedBusinessCardResponse(on request: Request, sharedBusinessCard: SharedBusinessCard) async throws -> Response {
        let businessCardsService = request.application.services.businessCardsService
        let sharedBusinessCardDto = businessCardsService.convertToDto(sharedBusinessCard: sharedBusinessCard,
                                                                      messages: nil,
                                                                      on: request.executionContext)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(SharedBusinessCardsController.uri)/@\(sharedBusinessCard.stringId() ?? "")")
        
        return try await sharedBusinessCardDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
