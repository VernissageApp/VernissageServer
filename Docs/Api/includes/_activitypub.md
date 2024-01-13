# Activity Pub

Endpoints used for registaring new user into the system.

## Shared inbox

```shell
curl "https://example.com/api/v1/shared/inbox" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

```swift
let request = URLRequest.shared
request.post()
```

> Example request body:

```json
{
  "@context": [
    "https://w3id.org/security/v1",
    "https://www.w3.org/ns/activitystreams",
    {
      "Hashtag": "as:Hashtag",
      "sensitive": "as:sensitive",
      "schema": "http://schema.org/",
      "pixelfed": "http://pixelfed.org/ns#",
      "commentsEnabled": {
        "@id": "pixelfed:commentsEnabled",
        "@type": "schema:Boolean"
      },
      "capabilities": {
        "@id": "pixelfed:capabilities",
        "@container": "@set"
      },
      "announce": {
        "@id": "pixelfed:canAnnounce",
        "@type": "@id"
      },
      "like": {
        "@id": "pixelfed:canLike",
        "@type": "@id"
      },
      "reply": {
        "@id": "pixelfed:canReply",
        "@type": "@id"
      },
      "toot": "http://joinmastodon.org/ns#",
      "Emoji": "toot:Emoji",
      "blurhash": "toot:blurhash"
    }
  ],
  "id": "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
  "type": "Create",
  "actor": "https://pixelfed.social/users/mczachurski",
  "published": "2024-01-10T07:13:25+00:00",
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "cc": [
    "https://pixelfed.social/users/mczachurski/followers",
    "https://gram.social/users/Alice"
  ],
  "object": {
    "id": "https://pixelfed.social/p/mczachurski/650595293594582993",
    "type": "Note",
    "summary": null,
    "content": "Extra colours!",
    "inReplyTo": "https://gram.social/p/Alice/650350850687790456",
    "published": "2024-01-10T07:13:25+00:00",
    "url": "https://pixelfed.social/p/mczachurski/650595293594582993",
    "attributedTo": "https://pixelfed.social/users/mczachurski",
    "to": [
      "https://www.w3.org/ns/activitystreams#Public"
    ],
    "cc": [
      "https://pixelfed.social/users/mczachurski/followers",
      "https://gram.social/users/Alice"
    ],
    "sensitive": false,
    "attachment": [],
    "tag": {
      "type": "Mention",
      "href": "https://gram.social/users/Alice",
      "name": "@Alice@gram.social"
    },
    "commentsEnabled": true,
    "capabilities": {
      "announce": "https://www.w3.org/ns/activitystreams#Public",
      "like": "https://www.w3.org/ns/activitystreams#Public",
      "reply": "https://www.w3.org/ns/activitystreams#Public"
    },
    "location": null
  }
}
```

`POST /api/v1/shared/inbox`

Endpoint for different kind of requests for Activity Pub protocol support.

## Get actor

```shell
curl "https://example.com/api/v1/actors/johndoe" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body (200 OK):

```json
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "attachment": [
        {
            "name": "MASTODON",
            "type": "PropertyValue",
            "value": "https://mastodon.social/@johndoe"
        },
        {
            "name": "GITHUB",
            "type": "PropertyValue",
            "value": "https://github.com/johndoe"
        }
    ],
    "endpoints": {
        "sharedInbox": "https://example.com/shared/inbox"
    },
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "icon": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    },
    "id": "https://example.com/actors/johndoe",
    "image": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    },
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "preferredUsername": "johndoe",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nM0Q....AB\n-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "tag": [
        {
            "href": "https://example.com/hashtag/Apple",
            "name": "Apple",
            "type": "Hashtag"
        },
        {
            "href": "https://example.com/hashtag/dotNET",
            "name": "dotNET",
            "type": "Hashtag"
        },
        {
            "href": "https://example.com/hashtag/iOS",
            "name": "iOS",
            "type": "Hashtag"
        }
    ],
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
```

`GET /api/v1/actors/:name`

Endpoint for download Activity Pub actor's data. One of the property is public key which should be used to validate requests done (and signed by private key) by the user in all Activity Pub protocol methods.

## Actor inbox

```shell
curl "https://example.com/api/v1/actors/johndoe/inbox" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

```swift
let request = URLRequest.shared
request.post()
```

`POST /api/v1/actors/:name/inbox`

## Actor outbox

```shell
curl "https://example.com/api/v1/actors/johndoe/outbox" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

```swift
let request = URLRequest.shared
request.post()
```

`POST /api/v1/actors/:name/outbox`

## Actor following

```shell
curl "https://example.com/api/v1/actors/johndoe/following" \
  -X GET \
  -H "Content-Type: application/json"
```

```shell
curl "https://example.com/api/v1/actors/johndoe/following?page=1" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body without page (200 OK):

```json
{
    "@context": "https://www.w3.org/ns/activitystreams",
    "first": "https://vernissage.photos/actors/mczachurski/following?page=1",
    "id": "https://vernissage.photos/actors/mczachurski/following",
    "totalItems": 8,
    "type": "OrderedCollection"
}
```

> Example response body with page (200 OK):

```json
{
    "@context": "https://www.w3.org/ns/activitystreams",
    "id": "https://vernissage.photos/actors/mczachurski/following?page=1",
    "orderedItems": [
        "https://pixelfed.social/users/AlanC",
        "https://pixelfed.social/users/moyamoyashashin",
        "https://vernissage.photos/actors/pczachurski",
        "https://pixelfed.social/users/mczachurski",
        "https://pixelfed.social/users/Devrin",
        "https://vernissage.photos/actors/jlara",
        "https://mastodon.social/users/mczachurski",
        "https://pxlmo.com/users/jfick"
    ],
    "partOf": "https://vernissage.photos/actors/mczachurski/following",
    "totalItems": 8,
    "type": "OrderedCollectionPage"
}
```

`GET /api/v1/actors/:name/following`

This is a list of everybody that the actor has followed.

## Actor followers

```shell
curl "https://example.com/api/v1/actors/johndoe/followers" \
  -X GET \
  -H "Content-Type: application/json"
```

```shell
curl "https://example.com/api/v1/actors/johndoe/followers?page=1" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body without page (200 OK):

```json
{
    "@context": "https://www.w3.org/ns/activitystreams",
    "first": "https://vernissage.photos/actors/mczachurski/followers?page=1",
    "id": "https://vernissage.photos/actors/mczachurski/followers",
    "totalItems": 6,
    "type": "OrderedCollection"
}
```

> Example response body with page (200 OK):

```json
{
    "@context": "https://www.w3.org/ns/activitystreams",
    "id": "https://vernissage.photos/actors/mczachurski/followers?page=1",
    "orderedItems": [
        "https://vernissage.photos/actors/pczachurski",
        "https://pixelfed.social/users/Devrin",
        "https://vernissage.photos/actors/jlara",
        "https://mastodon.social/users/mczachurski",
        "https://pxlmo.com/users/amiko",
        "https://pxlmo.com/users/jfick"
    ],
    "partOf": "https://vernissage.photos/actors/mczachurski/followers",
    "totalItems": 6,
    "type": "OrderedCollectionPage"
}
```

`GET /api/v1/actors/:name/followers`

This is a list of everyone who has sent a Follow activity for the actor.

## Actor status

```shell
curl "https://example.com/api/v1/actors/johndoe/statuses/7296951248933498881" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body (200 OK):

```json
{
    "@context": [
        "https://www.w3.org/ns/activitystreams"
    ],
    "attachment": [
        {
            "blurhash": "UGMtaO?b_3%M00Rj_3Rj~qD%IUM{j[ofD%-;",
            "exif": {
                "createDate": "2022-05-27T11:36:07+01:00",
                "exposureTime": "1/50",
                "fNumber": "f/8",
                "focalLenIn35mmFilm": "85",
                "lens": "Viltrox 85mm F1.8",
                "make": "SONY",
                "model": "ILCE-7M3",
                "photographicSensitivity": "100"
            },
            "height": 2731,
            "location": {
                "countryCode": "PL",
                "countryName": "Poland",
                "geonameId": "3081368",
                "latitude": "51,1",
                "longitude": "17,03333",
                "name": "Wrocław"
            },
            "mediaType": "image/jpeg",
            "name": "Feet visible from underneath through white foggy glass.",
            "type": "Image",
            "url": "https://s3.eu-central-1.amazonaws.com/vernissage/f154e5d151e441b18d61389f87cc877c.jpg",
            "width": 4096
        }
    ],
    "attributedTo": "https://vernissage.photos/actors/mczachurski",
    "cc": [
        "https://vernissage.photos/actors/mczachurski/followers"
    ],
    "content": "<p>Feet over the head <a href=\"https://vernissage.photos/tags/blackandwhite\">#blackandwhite</a> <a href=\"https://vernissage.photos/tags/streetphotography\">#streetphotography</a></p>",
    "id": "https://vernissage.photos/actors/mczachurski/statuses/7296951248933498881",
    "published": "2023-11-02T19:39:56.303Z",
    "sensitive": false,
    "tag": [
        {
            "href": "https://vernissage.photos/hashtag/blackandwhite",
            "name": "#blackandwhite",
            "type": "Hashtag"
        },
        {
            "href": "https://vernissage.photos/hashtag/streetphotography",
            "name": "#streetphotography",
            "type": "Hashtag"
        }
    ],
    "to": [
        "https://www.w3.org/ns/activitystreams#Public"
    ],
    "type": "Note",
    "url": "https://vernissage.photos/@mczachurski/7296951248933498881"
}
```

`GET /api/v1/actors/:name/statuses/:id`