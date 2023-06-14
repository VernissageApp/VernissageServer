---
title: API Reference

language_tabs: # must be one of https://github.com/rouge-ruby/rouge/wiki/List-of-supported-languages-and-lexers
  - shell
  - swift

toc_footers:
  - <a href='#'>Sign Up for a Developer Key</a>
  - <a href='https://github.com/slatedocs/slate'>Documentation Powered by Slate</a>

includes:
  - wellknow
  - nodeinfo
  - registration
  - account

code_clipboard: true

meta:
  - name: description
    content: Documentation for the Kittn API
---

# Introduction

Welcome to the Vernissage API! You can use our API to access Kittn API endpoints, which can get information on various cats,
kittens, and breeds in our database.

We have language bindings in Shell, Ruby, Python, and JavaScript! You can view code examples in the dark area to the right,
and you can switch the programming language of the examples with the tabs in the top right.

This example API documentation page was created with [Slate](https://github.com/slatedocs/slate).
Feel free to edit it and use it as a base for your own API's documentation.

## Identity columns

All objects contains own identity columnt `id`. That column is a big int (created by algorithm similar to Snowflakes),
howver in all JSON requests have to be send as a string.

## HTTP Headers

All requests have to contains headers.

Name | Value
--------- | -----------
Content-Type | application/json

## Supported languages

Messages returned by API are always on english. However during user registration there is an property `locale`.
That property is saved in the user profile, and thanks to this property communication in user can be done.
For example emails are send with choosen language.

Default in the system we can find two languages: `en_US`, `pl_PL`. More titles and translations can be added by system administrator.

