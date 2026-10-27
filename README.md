# Forge by 1344

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

ARM Services is the reference client. Its variables are `FORGE_FAQ_ENABLED`, `FORGE_REVIEWS_ENABLED`, and `FORGE_ARTICLES_ENABLED`, plus a shared `FORGE_URL` and `FORGE_API_TOKEN`. See that repo’s README for the fallback when a flag is `false` or the fetch fails. Content is read at **build** time.

## Local app

Ruby and Node versions are in `.ruby-version` / the Gemfile. Database URL comes from `DATABASE_URL` (see `config/database.yml`). Deploy with Kamal (`kamal init`).

Contact emails and website rebuilds are Active Job jobs. Sidekiq runs them against Redis (`REDIS_URL`, default `redis://127.0.0.1:6379/0`). `bin/dev` starts that worker as `jobs` (`bin/jobs`). Start Redis first, for example `docker run --rm -p 6379:6379 redis:7`.

In production Kamal runs a `job` container with the same image and a Redis accessory named `forge-redis`. Boot it once before the first deploy that enqueues work: `bin/kamal accessory boot redis`.

## Connect a GitHub repository to trigger a rebuild

Creating, updating, or deleting an article, FAQ, or review enqueues `DeliverWebsiteRebuildJob`. Sidekiq POSTs to the website’s rebuild URL. For GitHub Actions that URL is the repository dispatch endpoint, and the workflow then rebuilds the brochure site (which fetches published JSON from this API).

1. On the default branch of the brochure repository, add a workflow that listens for `forge-rebuild`:

```yaml
name: Rebuild from Forge
on:
  repository_dispatch:
    types: [forge-rebuild]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
```

`github.event.client_payload` contains `event` (`content.changed`), `content_type` (`articles`, `faqs`, or `reviews`), `website.domain`, and `updated_at`.

2. Create a fine-grained personal access token for that repository with **Contents: Read and write**. Repository dispatch needs the write permission.

3. In Forge, edit the website:

- Rebuild webhook URL: `https://api.github.com/repos/OWNER/REPO/dispatches`
- Rebuild bearer token: the personal access token
- Tick the content types this site fetches at build time (Blog articles, FAQs, Reviews). Match `FORGE_ARTICLES_ENABLED`, `FORGE_FAQ_ENABLED`, and `FORGE_REVIEWS_ENABLED`. Unticked types do not enqueue a rebuild.

The website must stay Active. Forge signs the raw body: header `X-Forge-Timestamp`, and `X-Forge-Signature: v1=` plus the hex HMAC-SHA256 of `{timestamp}.{body}` using the website’s rebuild secret (shown on the website page). It also sends `Authorization: Bearer` with the token above. GitHub starts the workflow when the token is valid; the site reads published content from the Forge API during the build.

## MCP / ChatGPT

Intégration optionnelle, désactivée par défaut : [configuration et workflow](docs/MCP.md).
Voir aussi [l'audit Rails et publication](docs/MCP_AUDIT.md).
