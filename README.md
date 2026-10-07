# ContentForge by 1344

Headless CMS. Writing happens here (admin, scoped to a `Website`). Brochure sites do not live in this repo: they read published JSON with that website’s API token and render it themselves.

## Public API

Base path: `/api/v1`. Every request needs the website token:

```
Authorization: Bearer <website api_token>
Accept: application/json
```

A missing or unknown token returns `401`. Responses only include rows for that website that are `published` and whose `published_at` is already in the past.

| Method | Path | Payload |
| --- | --- | --- |
| GET | `/api/v1/faqs` | `question`, `answer`, `slug`, `position`, `published_at` |
| GET | `/api/v1/reviews` | `author`, `content`, `rating` (integer 1–5), `position`, `published_at` |
| GET | `/api/v1/articles` | list: `title`, `slug`, `description`, `published_at`, `content_html` |
| GET | `/api/v1/articles/:slug` | one article, same object. Unknown, draft, or not-yet-published slug: `404` |

`rating` is required to publish a review. The admin example on each index page shows the same JSON.

## What stays on the brochure site

FAQ, reviews, and articles are the content a client edits here.

These stay in the site repository, not in this CMS:

- hero, services, process, coverage areas
- legal pages
- conversion (phone number, quote form)

The quote form still posts to `POST /api/v1/send_form` on this app. That is delivery, not a content type.

## Opt-in on the brochure site

This app does not store whether a site displays a block. Each brochure site turns FAQ, reviews, and articles on or off in its own environment (`true` or `false`), so one site can publish a blog and leave reviews in its own translations.

ARM Services is the reference client. Its variables are `CONTENTFORGE_FAQ_ENABLED`, `CONTENTFORGE_REVIEWS_ENABLED`, and `CONTENTFORGE_ARTICLES_ENABLED`, plus a shared `CONTENTFORGE_URL` and `CONTENTFORGE_API_TOKEN`. See that repo’s README for the fallback when a flag is `false` or the fetch fails. Content is read at **build** time.

## Local app

Ruby and Node versions are in `.ruby-version` / the Gemfile. Database URL comes from `DATABASE_URL` (see `config/database.yml`). Deploy with Kamal (`kamal init`).
