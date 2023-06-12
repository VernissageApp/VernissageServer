# Account

Endpoints used for tasks connected with user account.


## Login

```shell
curl "https://example.com/api/v1/account/login" \
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
    "userNameOrEmail": "johndoe",
    "password": "P@ssword1!"
}
```

> Example response body:

```json
{
    "accessToken": "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJyb2xlcyI6W10sInVzZXJOYW1lIjoibmlja2Z...",
    "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
}
```

Sign-in user via login (user nane or email) and password.


### Request properties

Property        | Type           | Description
----------------|----------------|--------------
userNameOrEmail | string(1...50) | User name or email.
password        | string(8...32) | Password.  

### Response properties

Property     | Type   | Description
-------------|--------|------
accessToken  | string | JWT access token.
refreshToken | string | Token which can be used to refresh `accessToken`.


### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
400    | invalidLoginCredentials      | Given user name or password are invalid.
403    | userAccountIsBlocked         | User account is blocked. User cannot login to the system right now.
403    | userAccountIsNotApproved     | User account is not aprroved yet. User cannot login to the system right now.
500    | saltCorrupted                | Password has been corrupted. Please contact with portal administrator.

## Confirm email

```shell
curl "https://example.com/api/v1/account/email/confirm" \
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
    "id": "7243149752689283073",
    "confirmationGuid": "fe4547e0-513d-40fb-8a1f-35c9e4beb8e9"
}
```

Endpoint should be used for email verification. During creating account special email is sending.
In that email there is a link to your website (with id and confirmationGuid as query parameters).
You have to create page which will read that parameters and it should send request to following endpoint.

### Request properties

Property         | Type           | Description
-----------------|----------------|--------------
id               | string(20)     | User id.
confirmationGuid | string(36)     | UUID which will be used to confirm email.  

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
400    | invalidIdOrToken             | Invalid user Id or token. Email cannot be approved.

## Resend email

```shell
curl "https://example.com/api/v1/account/email/resend" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [ACCESS_TOKEN]" \
  -d '{ ... }'
```

```swift
let request = URLRequest.shared
request.post()
```

> Example request body:

```json
{
    "redirectBaseUrl": "https://example.com"
}
```

Endpoint should be used for resending email for email verification. User have to be signed in into the system and `Bearer`
token have to be attached to the request.

### Request properties

Property         | Type           | Description
-----------------|----------------|--------------
redirectBaseUrl  | string         | Base url to web application. It's used to redirect from email about email confirmation to correct web application page. <br /> **format:** url <br /> **required**  

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
400    | emailIsAlreadyConfirmed      | Email is already confirmed.

## Change password

```shell
curl "https://example.com/api/v1/account/password" \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [ACCESS_TOKEN]" \
  -d '{ ... }'
```

```swift
let request = URLRequest.shared
request.post()
```

> Example request body:

```json
{
    "currentPassword": "P@ssword1!"
    "newPassword": "NewPassword1!"
}
```

Changing user password. In the request old and new passwords have to be specified and user have to be signed in into the system.

### Request properties

Property         | Type           | Description
-----------------|----------------|--------------
currentPassword  | string(8...32) | Old password for the account. <br /> **format:** password <br /> **required** 
newPassword      | string(8...32) | New password for the account. At least one lowercase letter, one uppercase letter, number or symbol. <br /> **format:** password <br /> **required**

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
400    | invalidOldPassword           | Given old password is invalid.
403    | userAccountIsBlocked         | User account is blocked. User cannot login to the system right now.
404    | userNotFound                 | Signed user was not found in the database.
403    | emailNotConfirmed            | User email is not confirmed. User have to confirm his email first.
500    | saltCorrupted                | Password has been corrupted. Please contact with portal administrator.

## Forgot password

```shell
curl "https://example.com/api/v1/account/forgot/token" \
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
    "email": "johndoe@example.com",
    "redirectBaseUrl": "https://example.com"
}
```

Sending email with token for authenticate changing password request. Url from email will redirect to client application (with token in query string).
Client application have to ask for new password and send new password and token from query string.

### Request properties

Property        | Type   | Description
----------------|--------|--------------
email           | string | Email which has been used during registration. <br /> **format:** email <br /> **required** 
redirectBaseUrl | string | Base url to web application. It's used to redirect from email about email to correct web application page. <br /> **format:** url <br /> **required**

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
403    | userAccountIsBlocked         | User account is blocked. User cannot login to the system right now.
404    | userNotFound                 | Signed user was not found in the database.

## Reset password

```shell
curl "https://example.com/api/v1/account/forgot/confirm" \
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
    "forgotPasswordGuid": "f0a5d44f-9f91-4514-b045-71cd096a84f2",
    "password": "newP@ssword1!"
}
```

Change password based on token from email.

### Request properties

Property           | Type           | Description
-------------------|----------------|--------------
forgotPasswordGuid | string(36)     | UUID which have been generated in previous request. <br /> **required** 
password           | string(8...32) | New password for the account. At least one lowercase letter, one uppercase letter, number or symbol. <br /> **format:** password <br /> **required**

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
400    | emailIsEmpty                 | User email is empty. Cannot send email with token.
403    | userAccountIsBlocked         | User account is blocked. You cannot change password right now.
403    | tokenExpired                 | Token which allows to change password expired. User have to repeat forgot password process.
500    | tokenNotGenerated            | Forgot password token wasn't generated. It's really strange.
500    | passwordNotHashed            | Password was not hashed successfully.
500    | saltCorrupted                | Password has been corrupted. Please contact with portal administrator.


## Refresh access token

```shell
curl "https://example.com/api/v1/account/refresh-token" \
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
    "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
}
```

> Example response body:

```json
{
    "accessToken": "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJyb2xlcyI6W10sInVzZXJOYW1lIjoibmlja2Z...",
    "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
}
```

Endpoint will regenerate new `access_token` based on `refresh_token` which has been generated during the login process.

### Request properties

Property     | Type   | Description
-------------|--------|--------------
refreshToken | string | Refresh token set up during the login process.

### Response properties

Property     | Type   | Description
-------------|--------|------
accessToken  | string | JWT access token.
refreshToken | string | Token which can be used to refresh `accessToken`.

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
403    | refreshTokenRevoked          | Refresh token was revoked.
403    | refreshTokenExpired          | Refresh token was expired.
403    | userAccountIsBlocked         | User account is blocked. You cannot change password right now.
404    | refreshTokenNotExists        | Refresh token not exists or it's expired.

## Revoke refresh tokens

```shell
curl "https://example.com/api/v1/account/refresh-token/@johndoe" \
  -H "Authorization: Bearer [ACCESS_TOKEN]" \
  -X DELETE
```

```swift
let request = URLRequest.shared
request.post()
```

Endpoint will revoke all refresh tokens created in context of specified in Url user. Access to that endpoint have administrator
and user mentioned in the Url (when user and `access_token` match).

### Errors

Status | Code                         | Reason
-------|------------------------------|-----------
400    | validationError              | Validation errors occurs.
404    | userNotFound                 | User not exists in the database.
