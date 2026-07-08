#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Check Node.js ────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  echo "ERROR: Node.js 18+ is required. Install from https://nodejs.org"
  exit 1
fi

NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: Node.js 18+ required. Current: $(node -v)"
  exit 1
fi

echo "Node.js $(node -v) detected."

# ── 1b. Ensure npm global prefix is user-writable ───────────────
NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")
if [ -n "$NPM_PREFIX" ] && [ ! -w "$NPM_PREFIX" ]; then
  echo "npm global prefix ($NPM_PREFIX) is not writable. Setting up user-local prefix..."
  USER_PREFIX="$HOME/.npm-global"
  mkdir -p "$USER_PREFIX"
  npm config set prefix "$USER_PREFIX"
  export PATH="$USER_PREFIX/bin:$PATH"
  # Add to bashrc if not already there
  if ! grep -q "$USER_PREFIX/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=\"$USER_PREFIX/bin:\$PATH\"" >> "$HOME/.bashrc"
  fi
  echo "  npm prefix set to $USER_PREFIX"
fi

# ── 2. Install playwright-cli ───────────────────────────────────
echo ""
echo "[1/7] Installing @playwright/cli globally..."
npm install -g @playwright/cli@latest

# ── 3. Install Playwright skills ────────────────────────────────
echo ""
echo "[2/7] Installing Playwright bundled skills..."
playwright-cli install --skills 2>/dev/null || echo "  (skipped — no agent detected)"

# ── 4. Install caveman skill ───────────────────────────────────
echo ""
echo "[3/7] Installing caveman skill (token compression)..."
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash 2>/dev/null || echo "  (skipped — install failed, continuing)"

# Merge caveman's opencode.json into opencode.jsonc if it was created
CAVEMAN_JSON="$HOME/.config/opencode/opencode.json"
OPENCODE_JSONC="$HOME/.config/opencode/opencode.jsonc"
if [ -f "$CAVEMAN_JSON" ]; then
  echo "  Merging caveman config into opencode.jsonc..."
  node -e "
const fs = require('fs');
const main = JSON.parse(fs.readFileSync('$OPENCODE_JSONC', 'utf8'));
const caveman = JSON.parse(fs.readFileSync('$CAVEMAN_JSON', 'utf8'));
if (caveman.plugin) {
  main.plugin = main.plugin || [];
  for (const p of caveman.plugin) {
    if (!main.plugin.includes(p)) main.plugin.push(p);
  }
}
fs.writeFileSync('$OPENCODE_JSONC', JSON.stringify(main, null, 2) + '\n');
fs.unlinkSync('$CAVEMAN_JSON');
console.log('  Caveman config merged.');
"
fi

# ── 5. Set up persistent browser profile ────────────────────────
echo ""
echo "[4/7] Setting up persistent browser profile for Google searches..."
PROFILE_DIR="$HOME/.cache/web-researcher"
mkdir -p "$PROFILE_DIR"

if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  echo ""
  echo "  A browser window will open. Please:"
  echo "    1. Accept Google's cookies (click 'Aceitar tudo' / 'Accept all')"
  echo "    2. If CAPTCHA appears, solve it"
  echo "    3. Close the browser window when done"
  echo ""
  echo "  Opening browser..."
  playwright-cli open --headed --persistent --profile="$PROFILE_DIR" https://www.google.com 2>/dev/null &
  PLAYWRIGHT_PID=$!
  echo "  Browser PID: $PLAYWRIGHT_PID"
  echo "  Waiting for you to complete (timeout: 120s)..."
  sleep 2
  WAITED=0
  while kill -0 "$PLAYWRIGHT_PID" 2>/dev/null && [ "$WAITED" -lt 120 ]; do
    sleep 3
    WAITED=$((WAITED + 3))
  done
  if kill -0 "$PLAYWRIGHT_PID" 2>/dev/null; then
    echo "  Timeout. Killing browser."
    kill "$PLAYWRIGHT_PID" 2>/dev/null || true
  fi
  echo "  Profile saved to $PROFILE_DIR"
else
  echo "  No display detected. Skipping manual Google setup."
  echo ""
  echo "  ⚠ IMPORTANT: Before your first search, run this manually:"
  echo "    playwright-cli open --headed --persistent --profile=$PROFILE_DIR https://www.google.com"
  echo "    Accept cookies, solve CAPTCHA if shown, then close the browser."
  echo "    After that, the sub-agent will work without CAPTCHAs."
fi

# ── 6. Copy shared skill ────────────────────────────────────────
echo ""
echo "[5/7] Copying web-research skill to ~/.claude/skills/..."
mkdir -p "$HOME/.claude/skills/web-research"
cp "$SCRIPT_DIR/skills/web-research/SKILL.md" "$HOME/.claude/skills/web-research/SKILL.md"
echo "  Done."

# ── 7. Copy opencode sub-agent ──────────────────────────────────
echo ""
echo "[6/7] Copying web-researcher sub-agent and instructions to opencode config..."
mkdir -p "$HOME/.config/opencode/agents"
cp "$SCRIPT_DIR/opencode/agents/web-researcher.md" "$HOME/.config/opencode/agents/web-researcher.md"
cp "$SCRIPT_DIR/opencode/instructions/web-research-instructions.md" "$HOME/.config/opencode/web-research-instructions.md"
echo "  Done."

# ── 8. Merge config patch ───────────────────────────────────────
echo ""
echo "[7/7] Merging config into ~/.config/opencode/opencode.jsonc..."

CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
PATCH_FILE="$SCRIPT_DIR/opencode/config-patch.jsonc"

# Create config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo '{ "$schema": "https://opencode.ai/config.json" }' > "$CONFIG_FILE"
fi

MERGE_SCRIPT="$(mktemp /tmp/web-researcher-merge.XXXXXX.js)"
cat > "$MERGE_SCRIPT" << 'MERGE_EOF'
const fs = require('fs');
const configPath = process.argv[2];
const patchPath = process.argv[3];

function stripJsonComments(text) {
  let result = '';
  let inString = false;
  let escape = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (escape) { result += ch; escape = false; continue; }
    if (ch === '\\' && inString) { result += ch; escape = true; continue; }
    if (ch === '"') { inString = !inString; result += ch; continue; }
    if (!inString && ch === '/' && text[i+1] === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      result += '\n';
      continue;
    }
    if (!inString && ch === '/' && text[i+1] === '*') {
      i += 2;
      while (i < text.length - 1 && !(text[i] === '*' && text[i+1] === '/')) i++;
      i++;
      continue;
    }
    result += ch;
  }
  return result;
}

const configText = fs.readFileSync(configPath, 'utf8');
const config = JSON.parse(stripJsonComments(configText));
const patch = JSON.parse(fs.readFileSync(patchPath, 'utf8'));

config.permission = config.permission || {};
for (const [k, v] of Object.entries(patch.permission || {})) {
  if (!(k in config.permission)) {
    config.permission[k] = v;
    console.log('  Added permission.' + k + ' = ' + JSON.stringify(v));
  } else {
    console.log('  permission.' + k + ' already set — skipping');
  }
}

// Merge instructions (array — add only new paths)
config.instructions = config.instructions || [];
if (patch.instructions) {
  for (const path of patch.instructions) {
    if (!config.instructions.includes(path)) {
      config.instructions.push(path);
      console.log('  Added instructions: ' + path);
    } else {
      console.log('  instructions: ' + path + ' already present — skipping');
    }
  }
}

config.agent = config.agent || {};
for (const [k, v] of Object.entries(patch.agent || {})) {
  if (!(k in config.agent)) {
    config.agent[k] = v;
    console.log('  Added agent.' + k);
  } else {
    console.log('  agent.' + k + ' already exists — skipping');
  }
}

fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
console.log('  Config written.');
MERGE_EOF

node "$MERGE_SCRIPT" "$CONFIG_FILE" "$PATCH_FILE"
rm -f "$MERGE_SCRIPT"

echo ""
echo "════════════════════════════════════════"
echo "  web-researcher installed successfully!"
echo "════════════════════════════════════════"
echo ""
echo "Components installed:"
echo "  - @playwright/cli (real browser automation)"
echo "  - caveman skill (token compression for sub-agent output)"
echo "  - web-research skill (shared: opencode + Claude Code)"
echo "  - web-research instructions (delegation rules for plan/build agents)"
echo "  - web-researcher sub-agent (opencode, model: opencode-go/deepseek-v4-flash)"
echo ""
echo "Next steps:"
echo "  1. Restart opencode (if running)"
echo "  2. Restart Claude Code (if running)"
echo "  3. Ask either tool to fetch a webpage — it will use Playwright."
