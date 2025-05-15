# Federation

## Supported federation protocols and standards

- [ActivityPub](https://www.w3.org/TR/activitypub/) (Server-to-Server)
- [WebFinger](https://webfinger.net/)
- [Http Signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures)
- [NodeInfo](https://nodeinfo.diaspora.software/)

## Supported FEPs

- [FEP-67ff: FEDERATION.md](https://codeberg.org/fediverse/fep/src/branch/main/fep/67ff/fep-67ff.md)
- [FEP-f1d5: NodeInfo in Fediverse Software](https://codeberg.org/fediverse/fep/src/branch/main/fep/f1d5/fep-f1d5.md)

## ActivityPub in Vernissage

Vernissage largely follows the ActivityPub server-to-server specification but it makes uses of some non-standard extensions, some of which are required for interacting with Mastodon at all.

- [Supported ActivityPub vocabulary](https://docs.joinvernissage.org/documentation/vernissageserver/activitypub)

### Required extensions

#### WebFinger

In Vernissage, users are identified by a `username` and `domain` pair (e.g., `mczachurski@vernissage.photos`).
This is used both for discovery and for unambiguously mentioning users across the fediverse.

As a result, Vernissage requires that each ActivityPub actor uniquely maps back to an `acct:` URI that can be resolved via WebFinger.

- [WebFinger information and examples](https://docs.joinvernissage.org/documentation/vernissageserver/webfinger)

#### HTTP Signatures

In order to authenticate activities, Vernissage relies on HTTP Signatures, signing every `POST` and `GET` request to other ActivityPub implementations on behalf of the user authoring an activity (for `POST` requests) or an actor representing the Mastodon server itself (for most `GET` requests).

Vernissage requires all `POST` requests to be signed, and MAY require `GET` requests to be signed, depending on the configuration of the Vernissage server.

- [HTTP Signatures information and examples](https://docs.joinvernissage.org/documentation/vernissageserver/httpsecurity)

### Optional extensions

- [geonameId](https://joinvernissage.org/ns#geonameId)
- [exif](https://joinvernissage.org/ns#exif)

## Additional documentation

- [Vernissage documentation](https://docs.joinvernissage.org/)
