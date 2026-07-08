---
name: web-research
description: Evaluate and choose between webfetch (fast, simple URLs) and web-researcher/playwright-cli (JS-heavy pages, search, bot-detected sites). Use ONLY when fetching web content or searching. Do NOT blindly delegate — evaluate the task first.
---

# Web Research

Evaluate the request and pick the right tool:

| Use `webfetch` | Use `web-researcher` / `playwright-cli` |
|---|---|
| Simple URLs (docs, APIs, static HTML) | Search queries |
| JSON endpoints, RSS feeds, `.txt`/`.json`/`.xml` | News sites, blogs, JS-heavy pages |
| GitHub READMEs, raw files | Paywalled or cookie-walled content |
| Known static sites (opencode.ai/docs, npmjs.com) | "Research", "find information about" |
| Fast response preferred | Any URL webfetch previously failed on |
| | Sites known to have bot detection / CAPTCHAs |

## Using webfetch

Just call the `webfetch` tool directly. It returns the page content as markdown.
Fast, minimal context usage.

## Using web-researcher (playwright-cli)

The `web-researcher` sub-agent runs a real Chromium browser.

### Fetch a URL

```bash
playwright-cli open <url>
playwright-cli eval "() => { const el = document.querySelector('article, main, [role=main]'); return el ? el.innerText : null; }"
```

Fallback to snapshot if eval returns null:

```bash
playwright-cli snapshot --depth=3
```

### Search the web

Use Google with persistent headed profile:

```bash
playwright-cli open --headed --persistent --profile=~/.cache/web-researcher https://www.google.com
# Accept cookies if prompted (find ref, click it)
playwright-cli type "your search query"
playwright-cli press Enter
playwright-cli snapshot --depth=2
```

Click into results and re-snapshot as needed.

### CAPTCHA recovery

If Google shows a CAPTCHA:

```bash
playwright-cli open --headed --persistent --profile=~/.cache/web-researcher https://www.google.com
# Solve CAPTCHA manually, accept cookies, close browser
# Resume normal search after
```

### Multi-page research

Use `goto` after the first `open`:

```bash
playwright-cli goto <other-url>
playwright-cli eval "() => { const el = document.querySelector('article, main, [role=main]'); return el ? el.innerText : null; }"
```

### Rules

- Always close the browser when done: `playwright-cli close`
- Return a clean summary — never raw snapshots.
- If content is missing (JS-heavy pages), wait briefly and retry.
- Prefer `eval` for content extraction — much less tokens than full snapshots.
