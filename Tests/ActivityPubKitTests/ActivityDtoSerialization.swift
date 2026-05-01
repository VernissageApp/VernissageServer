//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("ActivityDto serialization")
struct ActivityDtoSerialization {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
    }
    
    @Test
    func `Activity should serialize with simple single strings`() throws {
        // Arrange.
        let activityDto = ActivityDtoSerializationFixtures.createFollowActivityDto()
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        #expect(ActivityDtoSerializationFixtures.expectedFollowJson == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test
    func `Activity should serialize with single objects`() throws {
        // Arrange.
        let activityDto = ActivityDtoSerializationFixtures.createFollowActivityDto()
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        #expect(ActivityDtoSerializationFixtures.expectedFollowJson == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test
    func `Activity should serialize with attachments`() throws {
        // Arrange.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoSerializationFixtures.statusCase01.data(using: .utf8)!)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let activityDtoDeserialized = try self.decoder.decode(ActivityDto.self, from: jsonData)
        #expect(activityDtoDeserialized.object.objects().count == 1, "Object not serialized corretctly.")
        #expect((activityDtoDeserialized.object.objects().first?.object as? NoteDto)?.attachment?.count == 1, "Attachments not serialized corretctly.")
    }
    
    @Test
    func `Activity should serialize for annoucment`() throws {
        // Arrange.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoSerializationFixtures.statusCase03.data(using: .utf8)!)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let activityDtoDeserialized = try self.decoder.decode(ActivityDto.self, from: jsonData)
        #expect(activityDtoDeserialized.id == ActivityDtoSerializationFixtures.expectedAnnouncementId, "Create announe id should deserialize correctly")
        #expect(activityDtoDeserialized.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDtoDeserialized.actor.actorIds().first == ActivityDtoSerializationFixtures.expectedAnnouncementActor, "Create announe actor should deserialize correctly")
        #expect(activityDtoDeserialized.object.objects().first?.id == ActivityDtoSerializationFixtures.expectedAnnouncementObjectId, "Create announe object should deserialize correctly")
    }
    
    @Test
    func `Activity should serialize and deserialize target actor`() throws {
        // Arrange.
        let activityDto = ActivityDto(
            context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
            type: .move,
            id: "https://example.com/actor-a#move/123",
            actor: .single(ActorDto(id: "https://example.com/actor-a")),
            to: .single(ActorDto(id: "https://example.com/actor-a/followers")),
            object: .single(ObjectDto(id: "https://example.com/actor-a")),
            target: .single(ActorDto(id: "https://example.com/actor-b")),
            summary: nil,
            signature: nil,
            published: nil
        )
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        let deserialized = try self.decoder.decode(ActivityDto.self, from: jsonData)
        
        // Assert.
        #expect(deserialized.target?.actorIds().first == "https://example.com/actor-b")
    }
}
