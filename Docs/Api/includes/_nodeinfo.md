#  Node info

## Version 2.0

```shell
curl "https://example.com/api/v1/nodeinfo" \
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
    "openRegistrations": true,
    "services": {
        "inbound": [],
        "outbound": []
    },
    "protocols": [
        "activitypub"
    ],
    "software": {
        "name": "Vernissage",
        "version": "1.0"
    },
    "usage": {
        "users": {
            "total": 2,
            "activeMonth": 2,
            "activeHalfyear": 2
        },
        "localComments": 0,
        "localPosts": 0
    },
    "metadata": {
        "nodeName": "localhost"
    },
    "version": "2.0"
}no
```

[NodeInfo](http://nodeinfo.diaspora.software) is an effort to create a standardized way of exposing metadata about a server running one of the distributed social networks.
The two key goals are being able to get better insights into the user base of distributed social networking and the ability to build 
tools that allow users to choose the best fitting software and server for their needs.
