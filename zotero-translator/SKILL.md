---
name: zotero-translator
description: Write, test, install, and maintain custom Zotero web translators (the site-specific scrapers the Zotero Connector uses) with the official zotero/translators tooling. Use this whenever the user wants to save items from a website into Zotero, says the Connector only saves a generic "Web Page" for some site, asks for a "custom connector" or "translator" for a news site, journal, archive, or blog, wants to fix or extend an existing translator, or complains about wrong metadata (author, date, title, tags) when saving from a site, even if they never say "translator".
---

# Zotero web translators

A translator is one JavaScript file (`Label.js`) with a JSON header, `detectWeb`/`doWeb` functions, and embedded test cases. The Zotero Connector is generic; it fetches translators from the Zotero desktop client, which loads them from `<data directory>/translators/`. So "a custom connector for site X" always means "a translator for site X" installed into that folder.

Everything below wraps the official workflow in the `zotero/translators` repo. That repo ships its own agent guidance (`AGENTS.md`, `.agents/skills/develop-web-translator/SKILL.md`, `.agents/skills/create-test`, `verify-translator`) and `index.d.ts` with the sandbox API. Read `AGENTS.md` and the web-translator skill once per session; they are authoritative and maintained by Zotero. This skill adds the practical lessons that those files do not cover.

## 0. Set up the toolchain (once per machine or session)

```bash
scripts/setup-translators-repo.sh ~/path/for/translators-repo
```

It clones the repo with enough history for the linter (the ESLint plugin runs `git grep ... HEAD~1`, so a depth-1 clone makes `npm run lint` crash), selects Node 22 through nvm, and runs `npm ci`. The first `create-test`/`run-tests` call additionally clones and builds the Zotero Connector into `.ci/pull-request-check/connectors` (about 165 MB, one to three minutes) and drives the installed Google Chrome headless with that extension. Reuse one clone for all translators; the test tools serve every `*.js` in the repo root.

## 1. Analyze the site before writing anything

The translator can only use what is in the DOM, so inventory it first. Read `references/site-analysis.md` for the exact recipes. The questions to answer:

1. **Article URL shape.** Find a regex that matches article pages only (RT: `/<section>/<digits>-<slug>/`; TASS: `/<section>/<digits>`). Listing, tag, search, and topic pages must not match it.
2. **Metadata available on an article.** Open Graph tags, `<meta name=description>`, a schema.org `NewsArticle` JSON-LD block (headline, datePublished, dateModified, author, description, mainEntityOfPage), `<html lang>`, `article:section`, keywords. JSON-LD is usually the most reliable date source.
3. **Byline.** Where personal authors appear (RT: a closing `.article__author-text` with the name in `<strong>`), and whether news stories are unsigned agency copy (TASS). The metadata often names only the organization, which Embedded Metadata would turn into a bogus author like "Russia Today".
4. **Standfirst, section, tags.** The deck under the headline makes a better abstract than the meta description. Section may only exist in the `<title>` suffix or in site-navigation JSON-LD.
5. **Other page types.** Video/show episodes (RT `/shows/...` are `tvBroadcast` with `programTitle`), press reviews, opinion pieces with different byline markup, other-language editions on other subdomains (usually different templates; scope the target to the edition you analyzed).
6. **Listing pages in a real browser.** Use `node .bin/inspect-page.mjs <url> --eval '...'` to dump every anchor matching the article regex together with its ancestor classes. This is how you discover the traps: hidden mega-menus and sticky "latest news" feeds that preview stories on every page (TASS `.menu__content`), card links that wrap headline + summary in one anchor, lazy-loaded images whose `<noscript>` fallback shows up as literal `<img ...>` text in `textContent` (RT), and lists rendered by client-side JS that curl never sees.

A plain `curl` with a browser User-Agent is fine for server-rendered article pages and is faster than the browser tools; switch to `inspect-page.mjs` for anything rendered by JavaScript or whenever the pick-list looks wrong.

## 2. Scaffold

```bash
node .bin/init-translator.mjs --label "RT.com" --creator "Name" --target '^https?://(www\.)?rt\.com/' --type web
```

Conventions that matter:
- **Label** is the site name as users see it in Zotero's translator list. Use the domain form (`RT.com`, `TASS.com`, `NYTimes.com`) when the bare name is ambiguous or when other-language editions exist on other domains.
- **Target** should match only the edition you analyzed and end in `/` so proxied URLs are handled by Zotero.
- Leave `priority: 100` and `inRepository: true` as scaffolded; both are what the repo expects and neither harms a locally installed copy.
- The generated UUID is the translator's identity for updates. Never reuse one.

## 3. Write the code

Follow `.bin/templates/web.js` for shape (`detectWeb`, `getSearchResults`, `async doWeb`, `async scrape`) and delegate to Embedded Metadata (translator ID `951c027d-74ac-47d4-a107-9c3069ab7b48`) with an `itemDone` handler that fixes what EM gets wrong. `references/patterns.md` has the tested building blocks: JSON-LD extraction with `@graph` flattening, byline parsing, section mapping, tag merging, canonical URL, the generic anchor-based `getSearchResults` with heading preference, `linkText()` that strips `<noscript>` content, hidden-menu exclusion, and the `tvBroadcast` branch. Start from those rather than re-deriving them.

Rules of thumb that came from real failures:
- Reset `item.creators` and rebuild them from the byline; otherwise organization names leak in as people.
- Dates: `ZU.strToISO(linkedData.datePublished)`. Date-only ISO is the repo convention.
- Set `publicationTitle` explicitly to the outlet's name; EM's `og:site_name` may say "RT International".
- Keep the framework's auto-generated `shortTitle` (official Guardian, LA Times, Spiegel translators do), even when it looks odd for "Press review: ..." headlines.
- `getSearchResults` must dedupe by URL, prefer the headline element inside a card link, skip anchors whose text is empty after removing `<noscript>`, and skip anchors inside hidden menus or feeds. The test runner only asserts `"multiple"`, so verify the actual list (step 5).
- Pages the translator cannot detect fall through to `getSearchResults`, which is fine: a homepage or search page becomes a pick-list.

## 4. Lint, capture tests, run tests

```bash
node .bin/check-syntax.mjs RT.com.js
npm run lint -- RT.com.js                       # must report no errors
node .bin/create-test.mjs RT.com.js --url "<article url>"      # repeat per page type
node .bin/create-test.mjs RT.com.js --url "<listing url>"      # captures "multiple"
node .bin/update-metadata.mjs RT.com.js         # stamps lastUpdated; required after every code change
npm run lint -- RT.com.js
node .bin/run-tests.mjs RT.com.js --no-dependents
```

Capture at least one test per item type and per markup variant you handled (unsigned story, bylined feature, show episode, press review, listing). Never hand-write test items; `create-test` records exactly what the translator produces, and the linter enforces strict JSON in the test block. Run the browser tools one at a time: they share a Chrome profile lock.

When a test fails later because the live page changed (RT re-headlined a story within hours), the translator is usually fine. Remove the stale case and recapture:

```bash
python3 scripts/drop-test-case.py RT.com.js "<url substring>"
node .bin/create-test.mjs RT.com.js --url "<same url>"
node .bin/update-metadata.mjs RT.com.js && npm run lint -- RT.com.js && node .bin/run-tests.mjs RT.com.js --no-dependents
```

## 5. Verify the pick-list in a real browser

Replay the translator's `getSearchResults` logic through `inspect-page.mjs --eval` on a section page and a search page (snippet in `references/site-analysis.md`). Check that the first entries are the page's own stories, titles are clean text, and the count is plausible. This caught both the TASS mega-menu pollution and RT's `<img>` titles, which no automated test flags.

## 6. Deliver and install

```bash
scripts/install-translator.sh RT.com.js --keep-copy-in "/path/to/users/translator/folder"
```

The script locates the Zotero data directory from the profile's `prefs.js` (`extensions.zotero.dataDir`), copies the file into `<data dir>/translators/` without overwriting anything unless `--force`, and keeps a second copy in the user's own folder. Then tell the user, in this order:
1. Restart Zotero; translators are read at startup.
2. In the browser Connector's preferences, Advanced, click **Update Translators**, then reload the target page.
3. Keep the copy outside the data directory: Zotero's **Reset Translators** button wipes that folder.

Optionally confirm the client sees it (read-only, needs Zotero running and restarted):

```bash
curl -s -X POST http://127.0.0.1:23119/connector/getTranslators -H 'Content-Type: application/json' \
  -d '{"url":"https://www.rt.com/russia/646973-example/"}'
```

Also warn the user up front about one Connector limitation they will hit: when several items are saved at once from a pick-list, the Connector deliberately saves no snapshots (zotero-connectors issue 481). Single saves get snapshots. The "Add Missing Snapshots" plugin or a Run JavaScript backfill (see `references/install-and-connector.md`) repairs this afterwards.

## When to read which reference

- `references/patterns.md`: before writing `scrape`/`getSearchResults`; copy the helpers.
- `references/site-analysis.md`: when starting on a new site or when the pick-list looks wrong.
- `references/install-and-connector.md`: when installing, when "it doesn't show up", or when snapshots are missing.
