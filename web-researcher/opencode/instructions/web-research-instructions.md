# Web research

When you need to fetch a URL or search the internet, evaluate the request
before choosing a tool. This creates decision criteria in the web-research
skill.

## Decision criteria

| Use `webfetch` | Delegate to `web-researcher` sub-agent |
|---|---|
| Simple URLs (docs, APIs, static HTML) | Search queries ("find information about", "research") |
| JSON endpoints, RSS feeds | News sites, blogs, JS-heavy pages |
| GitHub READMEs, raw files | Paywalled or cookie-walled content |
| `.txt`, `.json`, `.xml` files | Any URL webfetch previously failed on |
| Fast response preferred | Sites known to have bot detection |
| opencode.ai/docs, npmjs.com | — |

## How to delegate

When `web-researcher` is the right choice, use the task tool:

```
task("research topic or URL", "...", subagent: "web-researcher")
```

The sub-agent runs a real Chromium browser via playwright-cli. It searches
Google, fetches pages, and returns a clean caveman-lite summary.

## How to use webfetch directly

```
webfetch("https://example.com", format: "markdown")
```

Fast, minimal context usage. Best for simple text-based URLs.
