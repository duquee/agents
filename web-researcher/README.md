# web-researcher

Real-browser web research agent that handles what `webfetch` cannot: JS-heavy
pages, search engines, and sites with bot detection. The parent agent evaluates
each request and picks the best tool — `webfetch` for simple URLs and APIs,
`web-researcher` for everything else.

## How it works

Uses [@playwright/cli](https://github.com/microsoft/playwright-cli) — a real
Chromium browser — to fetch web pages and search the web. Bypasses bot
detection, JS challenges, and CAPTCHAs that block simple HTTP fetchers.

Output is compressed using [caveman](https://github.com/JuliusBrussee/caveman)
lite mode — ~65% fewer tokens in the summary returned to the parent agent,
with all technical details preserved.

Works in both **opencode** and **Claude Code**.

| Tool | Mechanism |
|---|---|
| opencode | Parent evaluates request. Chooses `webfetch` allowed (no prompt) for simple URLs. `web-researcher` for search, news, JS-heavy pages. |
| Claude Code | Skill instructs the agent to evaluate and pick `webfetch` or `playwright-cli` |

## Install

```bash
./install.sh       # linux / macOS
# or
./install.ps1      # Windows
```

### What the installer does

1. Installs `@playwright/cli` globally via npm
2. Installs Playwright's bundled skills
3. Installs [caveman](https://github.com/JuliusBrussee/caveman) skill for token compression
4. Sets up persistent browser profile for Google (`--persistent --profile=~/.cache/web-researcher`)
5. Copies the `web-research` skill to `~/.claude/skills/` (shared by both tools)
6. Copies the instructions to `~/.config/opencode/web-research-instructions.md` (opencode only)
7. Copies the sub-agent to `~/.config/opencode/agents/` (opencode only)
8. Merges `webfetch: allow` + `instructions` + agent config into `~/.config/opencode/opencode.jsonc` (opencode only)

Safe to re-run — existing config keys are never overwritten.

### Requirements

- Node.js 18+
- opencode and/or Claude Code

## Usage

After installing, restart your tool. Then just ask naturally:

```
"Look up the Bun 2.0 release notes"
"Search for how to use React Server Components with Next.js"
"Fetch and summarize https://example.com/docs"
```

The agent automatically picks the right tool. Simple URLs and APIs use
`webfetch` (fast, zero setup). Searches, news sites, and JS-heavy pages
use Playwright.

## Model

The sub-agent is pinned to `opencode-go/deepseek-v4-flash` — the cheapest and
fastest model in the OpenCode Go lineup. Change it in `opencode.jsonc` if
you want a different model.

## Limitations

**Desktop only.** The web-researcher sub-agent runs `playwright-cli --headed`
which requires a local display (X11/Wayland). This works in:

| Mode | Works? |
|---|---|
| opencode (desktop / TUI) | Yes |
| Claude Code (desktop) | Yes |
| opencode Web | No — server has no display, playwright-cli not installed |
| opencode IDE | Only if the IDE runs on a machine with a display |

On web mode, `webfetch` remains available as fallback — it's configured as
`allow` (no prompt) for the parent agent.

## playwright-cli commands

| Command | Purpose |
|---|---|
| `playwright-cli open <url>` | Open browser and navigate to URL |
| `playwright-cli goto <url>` | Navigate to a new URL (after first open) |
| `playwright-cli snapshot` | Capture page content as structured text |
| `playwright-cli snapshot --depth=3` | Lean snapshot for simple pages |
| `playwright-cli type "text"` | Type text into the page |
| `playwright-cli press Enter` | Press a key |
| `playwright-cli click <ref>` | Click an element by ref from snapshot |
| `playwright-cli close` | Close the browser |
