//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension BusinessCardsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("business-cards")
    
    func boot(routes: RoutesBuilder) throws {
        let businessCardsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(BusinessCardsController.uri)
            .grouped(UserAuthenticator())
                
        businessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.businessCardsRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: read)
        
        businessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.businessCardsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        businessCardsGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.businessCardsUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(use: update)
    }
}

/// Exposing user's business card.
///
/// Endpoint is returning the information about user's business card. Business card can be shared with third party.
///
/// > Important: Base controller URL: `/api/v1/business-cards`.
struct BusinessCardsController {
        
    /// Get existing user's business card.
    ///
    /// The endpoint can be used for downloading existing user's business card.
    /// User can have one business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/business-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/business-cards" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "body": "Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
    ///     "color1": "#ad5389",
    ///     "color2": "#3c1053",
    ///     "color3": "#ffffff",
    ///     "createdAt": "2025-04-28T11:48:54.321Z",
    ///     "email": "",
    ///     "fields": [
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548099199",
    ///             "key": "MASTODON",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://user.dev"
    ///         },
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548101247",
    ///             "key": "WEBSITE",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://developer.dev"
    ///         }
    ///     ],
    ///     "id": "7498329715548097151",
    ///     "subtitle": "@johndoe",
    ///     "telephone": "",
    ///     "title": "John Doe",
    ///     "updatedAt": "2025-04-28T11:48:54.321Z",
    ///     "user": { ... },
    ///     "website": ""
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Entity data.
    @Sendable
    func read(request: Request) async throws -> BusinessCardDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }

        let businessCardsService = request.application.services.businessCardsService
        return businessCardsService.convertToDto(businessCard: businessCardFromDatabase, on: request.executionContext)
    }
    
    /// Create new user's business card.
    ///
    /// The endpoint can be used for creating new user's business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/business-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/business-cards" \
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
    ///     "body": "Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
    ///     "color1": "#ad5389",
    ///     "color2": "#3c1053",
    ///     "color3": "#ffffff",
    ///     "email": "",
    ///     "fields": [
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548099199",
    ///             "key": "MASTODON",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://user.dev"
    ///         },
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548101247",
    ///             "key": "WEBSITE",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://developer.dev"
    ///         }
    ///     ],
    ///     "id": "7498329715548097151",
    ///     "subtitle": "@johndoe",
    ///     "telephone": "",
    ///     "title": "John Doe",
    ///     "website": ""
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "body": "Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
    ///     "color1": "#ad5389",
    ///     "color2": "#3c1053",
    ///     "color3": "#ffffff",
    ///     "createdAt": "2025-04-28T11:48:54.321Z",
    ///     "email": "",
    ///     "fields": [
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548099199",
    ///             "key": "MASTODON",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://user.dev"
    ///         },
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548101247",
    ///             "key": "WEBSITE",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://developer.dev"
    ///         }
    ///     ],
    ///     "id": "7498329715548097151",
    ///     "subtitle": "@johndoe",
    ///     "telephone": "",
    ///     "title": "John Doe",
    ///     "updatedAt": "2025-04-28T11:48:54.321Z",
    ///     "user": { ... },
    ///     "website": ""
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
        
        let businessCardDto = try request.content.decode(BusinessCardDto.self)
        try BusinessCardDto.validate(content: request)
        
        let newBusinessCardId = request.application.services.snowflakeService.generate()
        let businessCard = BusinessCard(id: newBusinessCardId,
                                        userId: authorizationPayloadId,
                                        title: businessCardDto.title,
                                        subtitle: businessCardDto.subtitle,
                                        body: businessCardDto.body,
                                        website: businessCardDto.website,
                                        telephone: businessCardDto.telephone,
                                        email: businessCardDto.email,
                                        color1: businessCardDto.color1,
                                        color2: businessCardDto.color2,
                                        color3: businessCardDto.color3)
        
        var businessCardFields: [BusinessCardField] = []
        
        if let fields = businessCardDto.fields {
            for field in fields {
                let newFieldId = request.application.services.snowflakeService.generate()
                let newBusinessCardField = BusinessCardField(id: newFieldId,
                                                             businessCardId: newBusinessCardId,
                                                             key: field.key,
                                                             value: field.value)
                
                businessCardFields.append(newBusinessCardField)
            }
        }
        
        let businessCardFieldsToSave = businessCardFields
        try await request.db.transaction { database in
            try await businessCard.save(on: database)
            
            for businessCardFieldToSave in businessCardFieldsToSave {
                try await businessCardFieldToSave.save(on: database)
            }
        }
                
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }
                
        return try await createBusinessCardResponse(on: request, businessCard: businessCardFromDatabase)
    }
    
    /// Update existing user's business card.
    ///
    /// The endpoint can be used for updating existing user's business card.
    ///
    /// > Important: Endpoint URL: `/api/v1/business-cards`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/business-cards" \
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
    ///     "body": "Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
    ///     "color1": "#ad5389",
    ///     "color2": "#3c1053",
    ///     "color3": "#ffffff",
    ///     "email": "",
    ///     "fields": [
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548099199",
    ///             "key": "MASTODON",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://user.dev"
    ///         },
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548101247",
    ///             "key": "WEBSITE",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://developer.dev"
    ///         }
    ///     ],
    ///     "id": "7498329715548097151",
    ///     "subtitle": "@johndoe",
    ///     "telephone": "",
    ///     "title": "John Doe",
    ///     "website": ""
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "body": "Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
    ///     "color1": "#ad5389",
    ///     "color2": "#3c1053",
    ///     "color3": "#ffffff",
    ///     "createdAt": "2025-04-28T11:48:54.321Z",
    ///     "email": "",
    ///     "fields": [
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548099199",
    ///             "key": "MASTODON",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://user.dev"
    ///         },
    ///         {
    ///             "createdAt": "2025-04-28T11:48:54.324Z",
    ///             "id": "7498329715548101247",
    ///             "key": "WEBSITE",
    ///             "updatedAt": "2025-04-28T11:48:54.324Z",
    ///             "value": "https://developer.dev"
    ///         }
    ///     ],
    ///     "id": "7498329715548097151",
    ///     "subtitle": "@johndoe",
    ///     "telephone": "",
    ///     "title": "John Doe",
    ///     "updatedAt": "2025-04-28T11:48:54.321Z",
    ///     "user": { ... },
    ///     "website": ""
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    @Sendable
    func update(request: Request) async throws -> BusinessCardDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let businessCardDto = try request.content.decode(BusinessCardDto.self)
        try BusinessCardDto.validate(content: request)
                
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }
        
        businessCardFromDatabase.title = businessCardDto.title
        businessCardFromDatabase.subtitle = businessCardDto.subtitle
        businessCardFromDatabase.body = businessCardDto.body
        businessCardFromDatabase.website = businessCardDto.website
        businessCardFromDatabase.telephone = businessCardDto.telephone
        businessCardFromDatabase.email = businessCardDto.email
        businessCardFromDatabase.color1 = businessCardDto.color1
        businessCardFromDatabase.color2 = businessCardDto.color2
        businessCardFromDatabase.color3 = businessCardDto.color3
        
        var businessCardFieldToAdd: [BusinessCardField] = []
        var businessCardFieldToDelete: [BusinessCardField] = []
        var businessCardFieldToUpdate: [BusinessCardField] = []
        let fields = businessCardDto.fields ?? []
        
        // Calculate fields to update and delete.
        for businessCardFieldFromDb in businessCardFromDatabase.businessCardFields {
            if let flexiFieldDto = fields.first(where: { $0.id == businessCardFieldFromDb.stringId() }) {
                if flexiFieldDto.key == "" && flexiFieldDto.value == "" {
                    // User cleared key and value thus we can delete the whole row.
                    businessCardFieldToDelete.append(businessCardFieldFromDb)
                } else {
                    // Update existing one.
                    businessCardFieldFromDb.key = flexiFieldDto.key
                    businessCardFieldFromDb.value = flexiFieldDto.value
                    
                    businessCardFieldToUpdate.append(businessCardFieldFromDb)
                }
            } else {
                // Remember what to delete.
                businessCardFieldToDelete.append(businessCardFieldFromDb)
            }
        }
        
        // Calculate fields to add.
        for flexiFieldDto in fields {
            if flexiFieldDto.key == "" && flexiFieldDto.value == "" {
                continue
            }
            
            if businessCardFromDatabase.businessCardFields.contains(where: { $0.stringId() == flexiFieldDto.id }) == false {
                let newBusinessCardFieldId = request.application.services.snowflakeService.generate()
                let newBusinessCardField = try BusinessCardField(id: newBusinessCardFieldId,
                                                                 businessCardId: businessCardFromDatabase.requireID(),
                                                                 key: flexiFieldDto.key,
                                                                 value: flexiFieldDto.value)
                
                businessCardFieldToAdd.append(newBusinessCardField)
            }
        }
        
        
        let businessCardFieldToDatabaseAdd = businessCardFieldToAdd
        let businessCardFieldToDatabaseDelete = businessCardFieldToDelete
        let businessCardFieldToDatabaseUpdate = businessCardFieldToUpdate

        // Save everything to database in one transaction.
        try await request.db.transaction { database in
            try await businessCardFromDatabase.save(on: database)

            for businessCardField in businessCardFieldToDatabaseDelete {
                try await businessCardField.delete(on: database)
            }
            
            for businessCardField in businessCardFieldToDatabaseUpdate {
                try await businessCardField.update(on: database)
            }
            
            for businessCardField in businessCardFieldToDatabaseAdd {
                try await businessCardField.create(on: database)
            }
        }
        
        guard let businessCardFromDatabase = try await BusinessCard.query(on: request.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$user.$id == authorizationPayloadId)
            .first() else {
            throw EntityNotFoundError.businessCardNotFound
        }

        let businessCardsService = request.application.services.businessCardsService
        return businessCardsService.convertToDto(businessCard: businessCardFromDatabase, on: request.executionContext)
    }
    
    private func createBusinessCardResponse(on request: Request, businessCard: BusinessCard) async throws -> Response {
        let businessCardsService = request.application.services.businessCardsService
        let businessCardDto = businessCardsService.convertToDto(businessCard: businessCard, on: request.executionContext)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(BusinessCardsController.uri)/@\(businessCard.stringId() ?? "")")
        
        return try await businessCardDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
