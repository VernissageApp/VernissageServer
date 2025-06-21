# Using OAuth with Vernissage
This guide shows, step-by-step, how to register a client, obtain user consent, and exchange or refresh tokens, complete with sample payloads and code.

Vernissage implements two OAuth-related specifications to enable secure connections from native mobile applications:

- [RFC 7591](https://datatracker.ietf.org/doc/html/rfc7591) - OAuth 2.0 Dynamic Client Registration Protocol
- [RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749) - The OAuth 2.0 Authorization Framework

To access Vernissage’s API from a mobile app you will usually perform three high-level steps:

1. **Register a new OAuth client.**
2. **Open** /api/v1/oauth/authorize **to let the user grant access.**
3. **Exchange** the code returned by that page for an **access token** that you can include in subsequent API requests.

Each step is described in detail below.

---

## 1. Registering an OAuth client

An [endpoint](AuthenticationDynamicClientsController/register(request:)) has been added for creating the OAuth client: `POST /api/v1/auth-dynamic-clients`.

This endpoint implements [RFC 7591](https://datatracker.ietf.org/doc/html/rfc7591), so the full set of parameters and error codes can be found in that document.
Below is a minimal example payload (replace the placeholder values with those of your own application):

```json
{
  "client_name": "My Mobile App",
  "client_uri": "https://mymobileapp.org/",
  "contacts": ["info@mymobileapp.org"],
  "grant_types": ["authorization_code", "refresh_token"],
  "redirect_uris": ["mymobileapp-app://oauth-callback/mymobileapp"],
  "response_types": ["code"],
  "scope": "read write profile",
  "software_id": "da886f55-bf4e-4d6d-af0a-ad2f4d59e4d6",
  "software_version": "1.0.0"
}
```

In the example we request an OAuth client that supports two grant types (`authorization_code`, `refresh_token`) and one response type (`code`).

**Public vs. confidential clients**

If you need a confidential client (i.e. one with a client secret), include the optional `token_endpoint_auth_method` parameter:

| Value                 | Meaning                                                                                            |
|-----------------------|----------------------------------------------------------------------------------------------------|
| `none` (default)      | Public client - no client secret (OAuth 2.0 § 2.1).                                                |
| `client_secret_post`  | Confidential client - sends `client_id` + `client_secret` in the request body (OAuth 2.0 § 2.3.1). |
| `client_secret_basic` | Confidential client - uses HTTP Basic auth (OAuth 2.0 § 2.3.1). Currently not supported.           |

When you request a confidential client, Vernissage returns both a `client_id` and a `client_secret`. After sending the request shown above, the response contains exactly the same fields we sent, along with a few additional ones. The most important of these is `client_id`, and we will need its value later.

```json
{
  "client_id": "7518093054805281088",
  "client_id_issued_at": 1750442445,
  "client_name": "My Mobile App",
  "client_uri": "https://mymobileapp.org/",
  "contacts": ["info@mymobileapp.org"],
  "grant_types": ["authorization_code", "refresh_token"],
  "redirect_uris": ["mymobileapp-app://oauth-callback/mymobileapp"],
  "response_types": ["code"],
  "scope": "read write profile",
  "software_id": "da886f55-bf4e-4d6d-af0a-ad2f4d59e4d6",
  "software_version": "1.0.0"
}
```

Store the `client_id` (and `client_secret`, if provided) securely in your app and reuse them for all future log-in attempts - you do not need to register a new client every time.

## 2. Requesting user authorization

Once the client is registered, open the authorization page in the system browser or an authentication session. Below is a snippet of code from an iOS application (SwiftUI) that performs exactly this task.

```swift
@Environment(\.webAuthenticationSession) private var webAuthenticationSession

// 1. (Optional) Create a client as shown above.

// 2. Authorize the user.
let url = "https://vernissage.instance/api/v1/oauth/authorize?" +
    "response_type=code" + 
    "&client_id=7518093054805281088" +
    "&redirect_uri=mymobileapp-app://oauth-callback/mymobileapp" +
    "&state=c268e3d2-73a1-4af4-ba4b-9634f8fff367" +
    "&scope=read write profile"

let callbackURL = try await webAuthenticationSession.authenticate(
    using: URL(string: url)!,
    callbackURLScheme: "mymobileapp-app"
)

let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
let code = queryItems?.first { $0.name == "code" }?.value
```

The action above will display a login screen if the user is not already logged in. After logging in, the user will be redirected to a page where they must confirm that they want to authorize the application to access their data. If the user is already logged in, the authorization page is shown immediately.

Once the user authorizes access, the browser redirects the request to the URL defined in the `redirect_uri`. This URL also includes a `code` parameter, which can be exchanged for an access token.

## 3. Exchanging the authorization code for an access token

Once we have the `code`, we can exchange it for an access token, which can then be used in subsequent API requests (in the header: `Authorization: Bearer ...`). To do this, we need to send a `POST` request to the `/api/v1/oauth/token` [endpoint](OAuthController/token(request:)).

Request headers:
```
Content-Type: application/x-www-form-urlencoded
```

Request body:
```
grant_type=authorization_code&client_id=7518093054805281088&code=hgnbf9yrjmgjhe87yjwetrhfnb874yrk&redirect_uri=mymobileapp-app://oauth-callback/mymobileapp
```

This request will return a JSON response like the one shown below.

```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzUxMiJ9.eyJpZC...",
  "token_type": "bearer",
  "expires_in": "2025-06-27T20:08:41.510Z",
  "refresh_token": "qsqyUKLjmjhRrr4rUa9vtDX71eRdSCYN7DCiLPlo"
}
```

With these few steps, we have obtained an access token valid for 7 days, and a refresh token valid for 30 days. Include the access token in subsequent API calls: `Authorization: Bearer <access_token>`.

### Refreshing an access token

It’s a good practice to implement the application in a way that refreshes the access token before it expires (i.e., before the 7-day period ends), using the same endpoint. To do this, we need to send a request to `/api/v1/oauth/token` with the following parameters:


Request headers:
```
Content-Type: application/x-www-form-urlencoded
```

Request body:
```
grant_type=refresh_token&client_id=7518093054805281088&refresh_token=qsqyUKLjmjhRrr4rUa9vtDX71eRdSCYN7DCiLPlo
```

This request will return a JSON response containing a new access token and a new refresh token.
