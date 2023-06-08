# Vernissage API server

Application which is main API component for Vernissage.

Things todo:

[x] Sending the emails from the application (via Jobs)
[x] Change id into Snowflake'ish one
[ ] Change to new Vapor structure

[ ] Save external profile resources in the internal storage
[ ] Send internal resource to the CDN

[ ] Add more properties to the user table: avatar (URL), header (URL), statusesCount (Int), followersCount (Int), followingCount (Int).
[ ] Connect user to Hashtags based on description (bio)
[ ] User can have multiple property values (key/value pairs)

[ ] Deleting the user based on shared inbox queue (via Jobs)
[ ] Follow API (with sending to the Fediverse server via ActivityPub)
[ ] Unfollow API (with sending to the Fediverse server via ActivityPub)

[ ] Follow from ActivityPub
[ ] Unfollow from ActivityPub

[ ] Instance API
[ ] Statuses API (with MediaAttachments and Hashtags from note)
