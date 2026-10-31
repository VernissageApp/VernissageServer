//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Foundation
import Synchronization
import Testing
import Vapor

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Webfinger discovery")
struct WebfingerDiscoveryTests {
    @Test(arguments: ["direct", "xml", "json", "noactor", "malformed"])
    func `Resolves default endpoint before host-meta fallback`(scenario: String) async throws {
        // Arrange
        let host = "\(scenario)-\(UUID().uuidString.lowercased()).example"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebfingerDiscoveryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let application = try await Application.make(.testing)
        let baseUrl = try #require(URL(string: "https://\(host)"))

        let request = Request(application: application, on: application.eventLoopGroup.next())
        let service = ActivityPubDownloadUserService(urlSession: session)

        // Act
        let profile = await service.resolveActivityPubProfile(
            userName: "@steel_virgin@\(host)", baseUrl: baseUrl, on: request.executionContext)
        try await application.asyncShutdown()

        // Assert
        #expect(profile == "https://remote.example/channel/steel_virgin")
        let requests = WebfingerDiscoveryURLProtocol.requests.withLock { $0.removeValue(forKey: host) ?? [] }
        #expect(requests.map(\.url?.path) == (scenario == "direct"
            ? ["/.well-known/webfinger"] : ["/.well-known/webfinger", "/.well-known/host-meta", "/discovery"]))
        let first = try #require(requests.first)
        let resource = URLComponents(url: try #require(first.url), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "resource" }?.value
        #expect(resource == "acct:steel_virgin@\(host)")
        #expect(first.value(forHTTPHeaderField: "Accept") == "application/jrd+json, application/json;q=0.9, application/xrd+xml;q=0.8")
    }

    @Test(arguments: ["application/jrd+json; charset=utf-8", "Application/JSON; charset=UTF-8", "application/xrd+xml; charset=utf-8"])
    func `Decodes response according to its media type`(contentType: String) async throws {
        // Arrange
        var components = try #require(URLComponents(string: "https://content.example/document"))
        components.queryItems = [URLQueryItem(name: "contentType", value: contentType)]
        let url = try #require(components.url)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebfingerDiscoveryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = ActivityPubClient(urlSession: session)

        // Act
        let webfinger = try await client.webfinger(url: url)

        // Assert
        #expect(webfinger.subject == "acct:steel_virgin@remote.example")
        #expect(webfinger.activityPubProfile == "https://remote.example/channel/steel_virgin")
        if contentType.contains("xml") {
            #expect(webfinger.aliases == ["https://remote.example/~steel_virgin"])
            #expect(webfinger.links.first?.href == "https://remote.example/html?a=1&b=2")
        }
    }

    @Test(arguments: ["brokenxml", "html", "notfound"])
    func `Rejects invalid documents and unsuccessful responses`(scenario: String) async throws {
        // Arrange
        let url = try #require(URL(string: "https://\(scenario).example/document"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebfingerDiscoveryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = ActivityPubClient(urlSession: session)

        // Act
        let result: Result<WebfingerDto, any Error>
        do {
            result = .success(try await client.webfinger(url: url))
        } catch {
            result = .failure(error)
        }

        // Assert
        #expect(throws: (any Error).self) {
            try result.get()
        }
    }

    @Test
    func `Selects only ActivityStreams self links and prefers ActivityPub media type`() {
        // Arrange
        let ld = WebfingerLinkDto(rel: "self", type: "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"", href: "https://remote.example/ld")
        let html = WebfingerLinkDto(rel: "self", type: "text/html", href: "https://remote.example/html")
        let activity = WebfingerLinkDto(rel: "self", type: "application/activity+json", href: "https://remote.example/actor")
        let htmlOnly = WebfingerDto(subject: "acct:a@remote.example", aliases: nil, links: [html])
        let jsonLd = WebfingerDto(subject: "acct:a@remote.example", aliases: nil, links: [html, ld])
        let activityPub = WebfingerDto(subject: "acct:a@remote.example", aliases: nil, links: [html, ld, activity])

        // Act
        let htmlProfile = htmlOnly.activityPubProfile
        let jsonLdProfile = jsonLd.activityPubProfile
        let activityPubProfile = activityPub.activityPubProfile

        // Assert
        #expect(htmlProfile == nil)
        #expect(jsonLdProfile == ld.href)
        #expect(activityPubProfile == activity.href)
    }

    @Test
    func `Prefers JRD host-meta links and ignores empty templates`() {
        // Arrange
        let xml = """
        <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
            <Link rel="lrdd" type="application/json"/>
            <Link rel="lrdd" type="application/xrd+xml" template="https://remote.example/xrd?uri={uri}"/>
            <Link rel="lrdd" type="application/jrd+json" template="https://remote.example/jrd?resource={uri}"/>
        </XRD>
        """
        let service = ActivityPubDownloadUserService()

        // Act
        let link = service.getWebfingerLink(from: xml)

        // Assert
        #expect(link == "https://remote.example/jrd?resource={uri}")
    }
}

private final class WebfingerDiscoveryURLProtocol: URLProtocol {
    static let requests = Mutex<[String: [URLRequest]]>([:])
    private static let json = """
    {"subject":"acct:steel_virgin@remote.example","links":[
      {"rel":"self","type":"text/html","href":"https://remote.example/html"},
      {"rel":"self","type":"application/activity+json","href":"https://remote.example/channel/steel_virgin"}
    ]}
    """
    private static let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <x:XRD xmlns:x="http://docs.oasis-open.org/ns/xri/xrd-1.0">
      <x:Subject>acct:steel_virgin@remote.example</x:Subject>
      <x:Alias>https://remote.example/~steel_virgin</x:Alias>
      <x:Link rel="self" type="text/html" href="https://remote.example/html?a=1&amp;b=2"/>
      <x:Link rel="self" type="application/activity+json" href="https://remote.example/channel/steel_virgin"/>
    </x:XRD>
    """

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }

    override func startLoading() {
        guard let url = request.url, let host = url.host else { return }
        Self.requests.withLock { $0[host, default: []].append(request) }
        var status = 200
        var type = "application/jrd+json; charset=utf-8"
        var body = Self.json
        let contentType = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "contentType" })?.value
        if url.path == "/.well-known/host-meta" {
            type = "application/xrd+xml"
            body = """
            <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
              <Link rel="lrdd" type="application/xrd+xml" template="https://\(host)/discovery?uri={uri}"/>
            </XRD>
            """
        } else if url.path == "/.well-known/webfinger", host.hasPrefix("direct-") == false {
            if host.hasPrefix("noactor-") {
                body = "{\"subject\":\"acct:a@remote.example\",\"links\":[]}"
            } else if host.hasPrefix("malformed-") {
                body = "invalid JSON"
            } else {
                status = 404
                body = ""
            }
        } else if host.hasPrefix("xml-") || contentType?.contains("xml") == true {
            type = "application/xrd+xml"
            body = Self.xml
        } else if host == "brokenxml.example" {
            type = "application/xrd+xml"
            body = "<XRD>"
        } else if host == "html.example" {
            type = "text/html"
            body = "<html></html>"
        } else if host == "notfound.example" {
            status = 404
        }
        type = contentType ?? type
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": type]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
