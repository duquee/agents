# agents

A collection of AI coding agent configurations for opencode and Claude Code.

## Agents

| Agent | Description |
|---|---|
| [web-researcher](web-researcher/) | Fetches web pages and searches via Playwright real browser — bypasses bot detection that blocks webfetch |

## Installing

Install a single agent:

```bash
cd web-researcher && ./install.sh
```

Install all agents at once:

```bash
./install-all.sh
```

Each agent's installer copies skills and config to the right places and installs any dependencies. Safe to re-run.

## Adding a new agent

1. Create a new directory: `my-agent/`
2. Add a `README.md` describing what it does
3. Add an `install.sh` that copies files and installs dependencies
4. Add the agent to the table above

## Requirements

- Node.js 18+ (for agents that need npm packages)
- [opencode](https://opencode.ai) and/or [Claude Code](https://claude.ai)
