//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("ActivityDto deserialization")
struct ActivityDtoDeserialization {
    
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    init() {
        decoder.dateDecodingStrategy = .customISO8601
        encoder.dateEncodingStrategy = .customISO8601
        encoder.outputFormatting = .sortedKeys
    }
    
    @Test
    func `JSON with person string should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase01.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.actor == .single(ActorDto(id: "http://sally.example.org", type: nil)),
            "Single person name should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with person string arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase02.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org")
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person object should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase03.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.actor == .single(ActorDto(id: "http://sally.example.org", type: .person)),
            "Single person name should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with person object arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase04.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org", type: .person),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person mixed arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase05.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person emojis should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase06.data(using: .utf8)!)

        // Assert.
        #expect(personDto.tag?.tags().first?.name == ":verified:")
        #expect(personDto.tag?.tags().first?.type == .emoji)
    }
    
    @Test
    func `JSON with person emojis clear name should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase06.data(using: .utf8)!)

        // Assert.
        #expect(personDto.clearName() == "John Doe")
    }

    @Test
    func `JSON with person fields should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase07.data(using: .utf8)!)

        // Assert.
        #expect(personDto.attachment?[0].name == "MASTODON")
        #expect(personDto.attachment?[0].value == "https://mastodon.social/@johndoe")
        #expect(personDto.attachment?[0].type == "PropertyValue")
        
        #expect(personDto.attachment?[1].name == "GITHUB")
        #expect(personDto.attachment?[1].value == "https://github.com/johndoe")
        #expect(personDto.attachment?[1].type == "PropertyValue")
    }
    
    
    @Test
    func `JSON withouth manuallyApprovesFollowers field in person should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase08.data(using: .utf8)!)

        // Assert.
        #expect(personDto.manuallyApprovesFollowers == false)
    }
    
    @Test
    func `JSON with complex properties from brid.gy should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase09.data(using: .utf8)!)

        // Assert.
        #expect(personDto.manuallyApprovesFollowers == false)
    }

    @Test
    func `JSON with mixed PropertyValue and Link attachments should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase10.data(using: .utf8)!)

        // Assert.
        #expect(personDto.attachment?.count == 4)

        #expect(personDto.attachment?[0].type == "PropertyValue")
        #expect(personDto.attachment?[0].name == "Blog")
        #expect(personDto.attachment?[0].value != nil)

        #expect(personDto.attachment?[1].type == "Link")
        #expect(personDto.attachment?[1].name == "Blog")
        #expect(personDto.attachment?[1].value == nil)

        #expect(personDto.attachment?[2].type == "PropertyValue")
        #expect(personDto.attachment?[2].name == "GitHub")
        #expect(personDto.attachment?[2].value != nil)

        #expect(personDto.attachment?[3].type == "Link")
        #expect(personDto.attachment?[3].name == "GitHub")
        #expect(personDto.attachment?[3].value == nil)
    }
    
    @Test
    func `Only flexi fields should be returned from deserialized object by flexiField function`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase10.data(using: .utf8)!)

        // Assert.
        let flexiFields = personDto.flexiFields()
        #expect(flexiFields?.count == 2)
        
        #expect(flexiFields?[0].type == "PropertyValue")
        #expect(flexiFields?[0].name == "Blog")
        #expect(flexiFields?[0].value != nil)

        #expect(flexiFields?[1].type == "PropertyValue")
        #expect(flexiFields?[1].name == "GitHub")
        #expect(flexiFields?[1].value != nil)
    }
    
    @Test
    func `JSON with create status1 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.statusCase01.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://mastodon.social/users/mczachurski/statuses/111000972200397678/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with create status2 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.statusCase02.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://pixelfed.social/p/mczachurski/624592411232880406/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with create announce should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.statusCase03.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.id == "https://pixelfed.social/p/mczachurski/624586708985817828/activity", "Create announe id should deserialize correctly")
        #expect(activityDto.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDto.actor.actorIds().first == "https://pixelfed.social/users/mczachurski", "Create announe actor should deserialize correctly")
        #expect(activityDto.object.objects().first?.id == "https://mastodonapp.uk/@damianward/111322877716364793", "Create announe object should deserialize correctly")
    }
    
    @Test
    func `JSON with create announce and published should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.statusCase04.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.id == "https://mastodon.social/users/mczachurski/statuses/111330332088404363/activity", "Create announe id should deserialize correctly")
        #expect(activityDto.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDto.actor.actorIds().first == "https://mastodon.social/users/mczachurski", "Create announe actor should deserialize correctly")
        #expect(activityDto.object.objects().first?.id == "https://mastodon.social/users/TomaszSusul/statuses/111305598148116184", "Create announe object should deserialize correctly")
    }
    
    @Test
    func `JSON with create status5 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.statusCase05.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
            "Create status id should deserialize correctly"
        )
        
        let noteDto = activityDto.object.objects().first?.object as? NoteDto
        #expect(noteDto != nil, "Note should be deserialized")
    }
    
    @Test
    func `JSON with custom emoji should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: ActivityDtoDeserializationFixtures.statusCase07.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://server.social/users/dduser/statuses/113842725657361890", "Note id should deserialize correctly")
        #expect(noteDto.tag?.emojis().first != nil , "Emoji should be deserialized")
        #expect(noteDto.tag?.emojis().first?.name == ":KritischerTreffer:", "Emoji name should be deserialized")
        #expect(noteDto.tag?.emojis().first?.icon?.url == "https://server.social/system/custom_emojis/images/000/007/421/original/350499e0e0477dd7.png", "Emoji url should be deserialized")
    }
    
    @Test
    func `JSON from bsky.brid.gy should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: ActivityDtoDeserializationFixtures.statusCase08.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://bsky.brid.gy/convert/ap/at://did:plc:25pjv3klpvtyfupgodearyop/app.bsky.feed.post/3mhfimrpn5s2b", "Note id should deserialize correctly")
        #expect(noteDto.url == "https://bsky.brid.gy/r/https://bsky.app/profile/did:plc:25pjv3klpvtyfupgodearyop/post/3mhfimrpn5s2b", "Property 'url' is not valid.")
    }
    
    @Test
    func `JSON with person but without url string should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase11.data(using: .utf8)!)

        // Assert.
        #expect(personDto.id == "https://relay.fedi.buzz/tag/52challenge" , "Pserson id should deserialize.")
        #expect(personDto.url == nil, "Url should be nil when it's not exists in the JSON.")
    }
    
    @Test
    func `JSON with person from bluesky bridge should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase12.data(using: .utf8)!)

        // Assert.
        #expect(personDto.id == "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb" , "Pserson id should deserialize.")
        #expect(personDto.url?.values().first == "https://bsky.app/profile/snarfed.bsky.social", "Url should be nil when it's not exists in the JSON.")
    }
    
    @Test
    func `JSON from bsky.brid.gy with complex inReplyTo should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: ActivityDtoDeserializationFixtures.statusCase09.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4lxsz2s25", "Note id should deserialize correctly")
        #expect(noteDto.inReplyTo == "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225", "Property 'inReplyTo' is not valid.")
    }
    
    @Test
    func `JSON with person string and tag as s string should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(PersonDto.self, from: ActivityDtoDeserializationFixtures.personCase13.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.tag == .single(PersonHashtagDto(type: .unknown, name: "https://example.com/tag")),
            "Single person name should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with update person should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: ActivityDtoDeserializationFixtures.personCase14.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.actor == .single(ActorDto(id: "https://mastodon.art/users/alinamiko", type: nil)),
            "Update person should deserialize correctly"
        )
    }
}

