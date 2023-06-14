# WellKnow

## WebFinger

```shell
curl "https://example.com/.well-known/webfinger?resource=acct:johndoe@example.com" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body:

```json
{
    "subject": "acct:johndoe@example.com",
    "aliases": [
        "https://example.com/@johndoe",
        "https://example.com/actors/johndoe"
    ],
    "links": [
        {
            "rel": "http://webfinger.net/rel/profile-page",
            "type": "text/html",
            "href": "https://example.com/@mczachurski"
        },
        {
            "rel": "self",
            "type": "application/activity+json",
            "href": "https://example.com/actors/johndoe"
        }
    ]
}
```

`GET /.well-known/webfinger?resource=acct:johndoe@example.com`

Discover user on remote server.

## NodeInfo (https://github.com/jhass/nodeinfo)

```shell
curl "https://example.com/.well-known/nodeinfo" \
  -X GET \
  -H "Content-Type: application/json"
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body:

```json
{
    "links": [
        {
            "rel": "http://nodeinfo.diaspora.software/ns/schema/2.0",
            "href": "https://example.com/nodeinfo/2.0"
        }
    ]
}
```

`GET /.well-known/nodeinfo`

Discover url to NodeInfo endpoint.

## Host-meta (https://www.rfc-editor.org/rfc/rfc6415.html)

```shell
curl "https://example.com/.well-known/host-meta" \
  -X GET
```

```swift
let request = URLRequest.shared
request.post()
```

> Example response body:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="https://example.com/.well-known/webfinger?resource={uri}"/>
</XRD>
```

`GET /.well-known/host-meta`

Discover url to NodeInfo endpoint.
