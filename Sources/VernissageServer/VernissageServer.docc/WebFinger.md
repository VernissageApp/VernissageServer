# WebFinger

WebFinger translates `@user@domain` into its ActivityPub actor URL.

In Vernissage every account is uniquely identified by its full handle - `@username@domain` - because the same username can exist on many different servers. When you type only `@username` in a post, Vernissage assumes you are referring to someone on your own server and never looks beyond it. To reach a person on another server you must include the domain. Yet even `@alex@dogs.club` is only an alias: before any follow, mention, or reply can be delivered across the network, that alias has to be converted into the account’s canonical ActivityPub actor URL (the JSON document that lists its inbox, outbox, followers, and public key). The conversion happens through `WebFinger`, defined in `RFC 7033`. A Vernissage server sends an HTTPS request to https://dogs.club/.well-known/webfinger?resource=acct:alex@dogs.club and receives a small JSON response whose `"self"` link points to the actor, for example https://dogs.club/users/alex. The server then fetches that actor object and stores it locally so future interactions with `@alex@dogs.club` require no additional lookup.

Because WebFinger is the only standard discovery mechanism Vernissage recognizes, it is effectively mandatory: if a remote domain does not publish `/.well-known/webfinger` or does not respond with the expected `acct:` URI, other Vernissage instances cannot resolve its users, global search for `username@domain` fails, and any mention or follow originating elsewhere is undeliverable. Some non-Vernissage platforms try to bypass this by displaying their full actor URLs, but Vernissage’s internal logic still leans almost entirely on WebFinger and `acct:` URIs. In short, `@user@domain` is the human-friendly label. WebFinger is the DNS-like layer that turns that label into the precise ActivityPub address, and without it federation breaks down.

## Sample WebFinger flow

Suppose we want to lookup the user `@mczachurski` hosted on the `vernissage.photos` website.

Just make a request to that domain’s `/.well-known/webfinger` endpoint, with the resource query parameter set to an `acct:` URI. Request URL: `https://vernissage.photos/.well-known/webfinger?resource=acct:mczachurski@vernissage.photos`:

```json
{
  "aliases": [
    "https://vernissage.photos/@mczachurski",
    "https://vernissage.photos/actors/mczachurski"
  ],
  "links": [
    {
      "href": "https://vernissage.photos/actors/mczachurski",
      "rel": "self",
      "type": "application/activity+json"
    },
    {
      "href": "https://vernissage.photos/@mczachurski",
      "rel": "http://webfinger.net/rel/profile-page",
      "type": "text/html"
    }
  ],
  "subject": "acct:mczachurski@vernissage.photos"
}
```

You can parse this JSON response to find a link with your desired type. For ActivityPub id, we are interested in finding `application/activity+json` specifically.

This way, we have translated `@mczachurski@vernissage.photos` to `https://vernissage.photos/actors/mczachurski` and we can now interact over ActivityPub by referring to this URI as id where appropriate. Sample activity:

```json
{
"id": "https://social.example/activities/tu6ngi3neu",
"type": "Create",
"actor": "https://social.example/profiles/johndoe",
"object": {
    "id": "https://social.example/objects/g6khn84u",
    "type": "Note",
    "content": "Hello, Marcin!"
},
"to": "https://vernissage.photos/actors/mczachurski"
}
```

Note in the above example that social.example does not use the same (actor) URI structure as Vernissage. Thus, we cannot guess the actor id given only the username and domain. However, if social.example supports WebFinger, then we can get this id by requesting https://social.example/.well-known/webfinger?resource=acct:johndoe@social.example and parsing the response for a link with the `application/ld+json; profile="https://www.w3.org/ns/activitystreams"` or `application/activity+json` type. This link should also have the link relation `rel="self"`.
