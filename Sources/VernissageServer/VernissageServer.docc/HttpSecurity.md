# Http security

Remote request verification.

Vernissage authenticates every ActivityPub request with exactly the same HTTP Signature scheme that Mastodon describes in its security specification. Each inbound request must include a `Signature` header that:

1. points to the sender’s public key with keyId,
2. lists the headers that were signed (commonly (request-target) host date digest), and
3. contains a Base-64-encoded RSA-SHA256 signature of those header values.

When Vernissage receives the request it reconstructs the signed string, fetches the public key referenced by keyId, and verifies the signature. For POST requests it additionally checks the `Digest` header against the body and rejects any message whose `Date` header is older than 12 hours, ensuring both authenticity and integrity of the message.

See the full description in Mastodon’s documentation: [Mastodon Security — HTTP Signatures](https://docs.joinmastodon.org/spec/security/#http).
