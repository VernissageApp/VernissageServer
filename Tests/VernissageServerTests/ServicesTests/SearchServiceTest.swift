//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

@Suite("SearchService")
struct SearchServiceTests {
    
    @Test("Webfinger link should be found from simple Mastodon XML.")
    func webfingerLinkShouldBeFoundFromSimpleMastodonXML() throws {
        // Arrange.
        let searchService = SearchService()
        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="https://mastodon.social/.well-known/webfinger?resource={uri}"/>
</XRD>
"""

        // Act.
        let link = searchService.getWebfingerLink(from: xml)
        
        // Arrange.
        #expect(link == "https://mastodon.social/.well-known/webfinger?resource={uri}", "Webfinger link should be found.")
    }
    
    @Test("Webfinger link should be found from complex Fredrica XML.")
    func webfingerLinkShouldBeFoundFromComplexFredricaXML() throws {
        // Arrange.
        let searchService = SearchService()
        let xml = """
<?xml version=\"1.0\"?>\n<XRD xmlns:hm=\"http://host-meta.net/xrd/1.0\" xmlns:mk=\"http://salmon-protocol.org/ns/magic-key\" xmlns=\"http://docs.oasis-open.org/ns/xri/xrd-1.0\">\n  <hm:Host>loma.ml</hm:Host>\n  <link rel=\"lrdd\" type=\"application/xrd+xml\" template=\"https://loma.ml/xrd?uri={uri}\"/>\n  <link rel=\"lrdd\" type=\"application/json\" template=\"https://loma.ml/.well-known/webfinger?resource={uri}\"/>\n  <link rel=\"acct-mgmt\" href=\"https://loma.ml/amcd\"/>\n  <link rel=\"http://services.mozilla.com/amcd/0.1\" href=\"https://loma.ml/amcd\"/>\n  <Property type=\"http://salmon-protocol.org/ns/magic-key\" mk:key_id=\"1\">RSA.8IKwSxM_gfcoTgzRczR28GNjSoS5HU2ebyN-0E1UT-48NGCH6MCY6SzpC7qGIpNjaPAarWG2KXv0EnFLU6Lan-op92UncpnFQerlGM0GNpF7HSP3VDDsi3pjZ8f1GUcpM9H6mglnCJFObdWoKkZ9OMH3ymQqmShlLEKKkfGM9u8.AQAB</Property>\n</XRD>
"""
        
        // Act.
        let link = searchService.getWebfingerLink(from: xml)
        
        // Arrange.
        #expect(link == "https://loma.ml/.well-known/webfinger?resource={uri}", "Webfinger link should be found.")
    }
    
    @Test("Webfinger link should be found from missing JSON Misskey XML.")
    func webfingerLinkShouldBeFoundFromMissingJsonMisskeyXML() throws {
        // Arrange.
        let searchService = SearchService()
        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" type="application/xrd+xml" template="https://misskeymint.net/.well-known/webfinger?resource={uri}"/>
</XRD>
"""
        
        // Act.
        let link = searchService.getWebfingerLink(from: xml)
        
        // Arrange.
        #expect(link == "https://misskeymint.net/.well-known/webfinger?resource={uri}", "Webfinger link should be found.")
    }
}
