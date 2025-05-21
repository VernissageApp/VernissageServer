# ActivityPub

A decentralized social networking protocol based upon the ActivityStreams 2.0 data format and JSON-LD.

- [Status federation](#Status-federation)
- [Profile federation](#Profile-federation)
- [Extensions](#Extensions)

## Status federation

Supported activities for statuses (photos):

- `Create` - transformed info status and saved into database.
- `Delete` - removes a status from database.
- `Like` - transformed into a favourite on a status.
- `Announce` - transformed into a boost on a status.
- `Undo` - undo a previous `Like` or `Annouce`.

### Schema

Vernissage supports only object type `Note`. Notes are transformed into regular statuses (photos). 

> Note: Vernissage can only display notes that include images in the attachment collection.

Notes without any images are not saved to the database. However, if a note is a reply to a previously fetched note (which must include an image), it will be saved to the database.

Used properties:

- `id` - saved as ActivityPub object identifier.
- `content` - used as a status text.
- `summary` - used as content warning text.
- `inReplyTo` - used for threading a status as a reply to another status.
- `published` - used as status date.
- `url` - used for status permalinks.
- `attributedTo` - used to determine the profile which authored the status.
- `to`/`cc` - used to determine audience and visibility of a status, in combination with mentions.
- `sensitive` - used to determine whether status media or text should be hidden by default.
- `tag` - used to mark up mentions, hashtags or emojis (collection of `NoteTagDto`).
- `attachment` - used to include attached images (collection of `MediaAttachmentDto`).

Properties of `NoteTagDto`:

- `type` - either `Mention`, `Hashtag`, or `Emoji` is currently supported.
- `name` - the plain-text Webfinger address of a profile `Mention` (@user or @user@domain), or the plain-text `Hashtag` (#tag), or the custom `Emoji` shortcode (:thounking:).
- `href` - the URL of the actor or tag.
- `icon` - information about emoji (`NoteTagIconDto` object).
- `updated` - date when emoji has been updated.

Properties of `NoteTagIconDto`:

- `type` - type of the icon, `Image` is supported only.
- `mediaType` - mime type of the icon.
- `url` - url to the file icon.

Properties of `MediaAttachmentDto`:

- `url` - used to fetch the media attachment.
- `name` - used as media description (ALT text).
- `mediaType` - used to distinguish if attachment is an image.

Extensions in `MediaAttachmentDto`:

- `blurhash` - used to generate a blurred preview image corresponding to the colors used within the image (see: https://docs.joinmastodon.org/spec/activitypub/#blurhash)
- `exif` - metadata information about the image (see: https://joinvernissage.org/ns#exif).
- `location` - extension from https://schema.org (extension: `addressCountry`, type: `Place`).
- `location.geonameId` - additional extension to location (see: https://joinvernissage.org/ns#geonameId).

### JSON+LD Example

```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    {
      "addressCountry": "schema:addressCountry",
      "blurhash": "toot:blurhash",
      "exif": "photos:exif",
      "geonameId": "photos:geonameId",
      "Category": "photos:Category",
      "photos": "https://joinvernissage.org/ns#",
      "schema": "https://schema.org",
      "toot": "http://joinmastodon.org/ns#"
    }
  ],
  "attachment": [
    {
      "blurhash": "U1AJ~A_300_300009Fof?b4nIUt7xu%MD%4n",
      "exif": {
        "createDate": "2025-02-27T17:38:49.408Z",
        "exposureTime": "1/200",
        "fNumber": "f/2.2",
        "flash": "Flash did not fire, compulsory flash mode",
        "focalLenIn35mmFilm": "85",
        "focalLength": "85",
        "latitude": "51.110501666666664N",
        "lens": "Zeiss Batis 1.8/85",
        "longitude": "17.033457778333332E",
        "make": "SONY",
        "model": "ILCE-7M4",
        "photographicSensitivity": "3200"
      },
      "height": 2731,
      "location": {
        "addressCountry": "PL",
        "geonameId": "3081368",
        "latitude": "51,1",
        "longitude": "17,03333",
        "name": "Wrocław",
        "type": "Place"
      },
      "mediaType": "image/jpeg",
      "name": "The image is in black and white, showing a cafe with tables and chairs.",
      "type": "Image",
      "url": "https://vernissage.instance/storage/eeb75ee9252a4f1192d8d66be2dcf962.jpg",
      "width": 4096
    }
  ],
  "attributedTo": "https://vernissage.instance/actors/johndoe",
  "cc": [
    "https://vernissage.photos/actors/mczachurski/followers"
  ],
  "content": "<p>Waiting...<br /><br /><a href=\"https://vernissage.instance/tags/Photography\" rel=\"tag\" class=\"mention hashtag\">#Photography</a> <a href=\"https://vernissage.instance/tags/Street\" rel=\"tag\" class=\"mention hashtag\">#Street</a> <a href=\"https://vernissage.instance/tags/StreetPhotography\" rel=\"tag\" class=\"mention hashtag\">#StreetPhotography</a> <a href=\"https://vernissage.instance/tags/BlackAndWhite\" rel=\"tag\" class=\"mention hashtag\">#BlackAndWhite</a> <a href=\"https://vernissage.instance/tags/BlackAndWhitePhotography\" rel=\"tag\" class=\"mention hashtag\">#BlackAndWhitePhotography</a></p>",
  "id": "https://vernissage.instance/actors/johndoe/statuses/7500892058677152209",
  "published": "2025-05-05T09:32:06.508Z",
  "sensitive": false,
  "tag": [
    {
      "href": "https://vernissage.instance/tags/BlackAndWhite",
      "name": "#BlackAndWhite",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/BlackAndWhitePhotography",
      "name": "#BlackAndWhitePhotography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Photography",
      "name": "#Photography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Street",
      "name": "#Street",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/StreetPhotography",
      "name": "#StreetPhotography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/categories/Street",
      "name": "Street",
      "type": "Category"
    }
  ],
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "type": "Note",
  "url": "https://vernissage.instance/@johndoe/7500892058677152209"
}
```

## Profile federation

Supported activities for profiles:

- `Follow` - indicate interest in receiving status updates from a profile.
- `Accept`/`Reject` - used to approve or deny `Follow` activities. Unlocked accounts will automatically reply with an `Accept`, while locked accounts can manually choose whether to approve or deny a follow request.
- `Update` - refresh account details.
- `Delete` - remove an account from the database, as well as all of their statuses.
- `Undo` - Undo a previous `Follow`.

### Schema

Used properties:
- `id` - saved as ActivityPub object identifier.
- `preferredUsername` - used for Webfinger lookup. Must be unique on the domain, and must correspond to a Webfinger acct: URI.
- `name` - used as profile display name.
- `summary` - used as a profile bio.
- `type` - assumed to be `Person`. If type is `Application` or `Service`, it will be interpreted as a bot flag.
- `url` - used as profile link.
- `icon` - used as profile avatar.
- `image` - used as profile header.
- `manuallyApprovesFollowers` - will be shown as a locked account.
- `publicKey` - required for signatures (object `PersonPublicKeyDto`).
- `attachment` - used for profile fields (collection of `PersonAttachmentDto`)
- `alsoKnownAs` - required for Move activity (collection of strings).
- `tag` - used to mark up hashtags or emojis (collection of `PersonHashtagDto`).
- `published` - when the profile was created.
- `endpoints` - a json object which maps additional (typically server/domain-wide) endpoints which may be useful either for this actor or someone referencing this actor.
- `inbox` - a reference to an [ActivityStreams] OrderedCollection comprised of all the messages received by the actor.
- `outbox` - an [ActivityStreams] OrderedCollection comprised of all the messages produced by the actor.
- `following` - a link to an [ActivityStreams] collection of the actors that this actor is following.
- `followers` - a link to an [ActivityStreams] collection of the actors that follow this actor.

Properties of `PersonPublicKeyDto`:

- `id` - public key identifier.
- `owner` - url to public key owner.
- `publicKeyPem` - public key PEM.

Properties of `PersonAttachmentDto`:

- `type` - only `PropertyValue` extension from https://schema.org is supported.
- `name` - name of the property.
- `value` - value of the property.

Properties of `PersonHashtagDtoDto`:

- `name` - the plain-text `Hashtag` (#tag), or the custom `Emoji` shortcode (:thounking:).
- `href` - the URL of the tag.
- `icon` - information about emoji (`PersonImageDto` object).

Properties of `PersonImageDto`:

- `type` - type of the icon, `Image` is supported only.
- `mediaType` - mime type of the icon.
- `url` - url to the file icon.

### JSON+LD Example

```json
{
  "@context": [
    "https://w3id.org/security/v1",
    "https://www.w3.org/ns/activitystreams",
    {
      "PropertyValue": "schema:PropertyValue",
      "alsoKnownAs": {
        "@id": "as:alsoKnownAs",
        "@type": "@id"
      },
      "manuallyApprovesFollowers": "as:manuallyApprovesFollowers",
      "schema": "https://schema.org",
      "toot": "http://joinmastodon.org/ns#"
    }
  ],
  "alsoKnownAs": [
    "https://example.social/users/johndoe"
  ],
  "attachment": [
    {
      "name": "HOMEPAGE",
      "type": "PropertyValue",
      "value": "<a href=\"https://johndoe.dev\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>johndoe.dev</a>"
    },
    {
      "name": "MASTODON",
      "type": "PropertyValue",
      "value": "<a href=\"https://example.social/@johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>example.social/@johndoe</a>"
    }
  ],
  "endpoints": {
    "sharedInbox": "https://vernissage.photos/shared/inbox"
  },
  "followers": "https://vernissage.instance/actors/johndoe/followers",
  "following": "https://vernissage.instance/actors/johndoe/following",
  "icon": {
    "mediaType": "image/jpeg",
    "type": "Image",
    "url": "https://vernissage.instance/storage/2043486227r84b5366d52hfddc666149.png"
  },
  "id": "https://vernissage.instance/actors/johndoe",
  "image": {
    "mediaType": "image/jpeg",
    "type": "Image",
    "url": "https://vernissage.instance/storage/564a5c1de4014h2db859jc2be4627cb7.jpg"
  },
  "inbox": "https://vernissage.instance/actors/johndoe/inbox",
  "manuallyApprovesFollowers": false,
  "name": "John Doe",
  "outbox": "https://vernissage.instance/actors/johndoe/outbox",
  "preferredUsername": "johndoe",
  "publicKey": {
    "id": "https://vernissage.instance/actors/johndoe#main-key",
    "owner": "https://vernissage.instance/actors/johndoe",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nMIIBBAQEFAAO...NVy8d\n/wIDAQAB\n-----END PUBLIC KEY-----"
  },
  "published": "2023-07-01T06:19:36.378Z",
  "summary": "👨🏻‍💻 Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
  "tag": [
    {
      "href": "https://vernissage.instance/tags/dotNET",
      "name": "dotNET",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Swift",
      "name": "Swift",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Angular)",
      "name": "Angular)",
      "type": "Hashtag"
    }
  ],
  "type": "Person",
  "url": "https://vernissage.instance/@johndoe"
}
```

## Extensions

The Vernissage platform introduces additional fields to ActivityPub objects to enhance the experience
of publishing and consuming photographic content. These extensions are primarily intended for
applications focused on photography and visual media. The fields are added using custom context
definitions and are compatible with the ActivityStreams JSON-LD structure.

Base URI: [https://joinvernissage.org/ns#](https://joinvernissage.org/ns#)

Contains terms used for Vernissage features:
- [geonameId](https://joinvernissage.org/ns#geonameId) — geonameId property for GeoNames identifier.
- [exif](https://joinvernissage.org/ns#exif) — exif property for camera metadata.
- [Category](https://joinvernissage.org/ns#Category) — Category property for categorizing entity.
