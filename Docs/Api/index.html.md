---
title: API Reference

language_tabs: # must be one of https://github.com/rouge-ruby/rouge/wiki/List-of-supported-languages-and-lexers
  - shell
  - swift

toc_footers:
  - Vernissage API documentation

includes:
  - wellknow
  - nodeinfo
  - activitypub
  - registration
  - account
  - attachments
  - avatars
  - categories
  - countries
  - followrequests
  - headers
  - instance
  - invitations
  - locations
  - notifications
  - relationships
  - reports
  - roles
  - search
  - settings
  - statuses
  - timelines
  - trending
  - users

code_clipboard: true

meta:
  - name: description
    content: Documentation for the Kittn API
---

# Introduction

Welcome to the Vernissage API documentation!

Vernissage is an application for sharing your photographs with other system users. It is an application that,
thanks to the implemented ActivityPub protocol, allows you to exchange information with different systems from Fediverse,
such as Pixelfed, Mastodon and others.

You can use our API to access Vernissage API endpoints, which can get information on statuses,
attachments, users and more in our database.

This API documentation page was created with [Slate](https://github.com/slatedocs/slate).

## Identity columns

All objects contains own identity columnt `id`. That column is a big int (created by algorithm similar to Snowflakes),
howver in all JSON requests have to be send as a string.

## HTTP Headers

All requests have to contains headers.

Name         | Value            |
-------------| -----------------|
Content-Type | application/json |

## Supported languages

Messages returned by API are always on english. However during user registration there is an property `locale`.
That property is saved in the user profile, and thanks to this property communication in user can be done.
For example emails are send with choosen language.

Default in the system we can find two languages: `en_US`, `pl_PL`. More titles and translations can be added by system administrator.

