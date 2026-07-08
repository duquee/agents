#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── 1. Check Node.js ────────────────────────────────────────────
try {
    $nodeVersion = (node -v) -replace 'v','' -split '\.'
    $nodeMajor = [int]$nodeVersion[0]
    if ($nodeMajor -lt 18) {
        Write-Host "ERROR: Node.js 18+ required. Current: $(node -v)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Node.js $(node -v) detected."
} catch {
    Write-Host "ERROR: Node.js 18+ is required. Install from https://nodejs.org" -ForegroundColor Red
    exit 1
}

# ── 2. Install playwright-cli ───────────────────────────────────
Write-Host ""
Write-Host "[1/7] Installing @playwright/cli globally..." -ForegroundColor Cyan
npm install -g @playwright/cli@latest

# ── 3. Install Playwright skills ────────────────────────────────
Write-Host ""
Write-Host "[2/7] Installing Playwright bundled skills..." -ForegroundColor Cyan
try { playwright-cli install --skills } catch { Write-Host "  (skipped)" }

# ── 4. Install caveman skill ───────────────────────────────────
Write-Host ""
Write-Host "[3/7] Installing caveman skill (token compression)..." -ForegroundColor Cyan
try {
    irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
} catch { Write-Host "  (skipped — install failed, continuing)" }

# Merge caveman's opencode.json into opencode.jsonc if it was created
$cavemanJson = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
$opencodeJsonc = Join-Path $env:USERPROFILE ".config\opencode\opencode.jsonc"
if (Test-Path $cavemanJson) {
    Write-Host "  Merging caveman config into opencode.jsonc..." -ForegroundColor Cyan
    node -e "
const fs = require('fs');
const main = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
const caveman = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (caveman.plugin) {
  main.plugin = main.plugin || [];
  for (const p of caveman.plugin) {
    if (!main.plugin.includes(p)) main.plugin.push(p);
  }
}
fs.writeFileSync(process.argv[1], JSON.stringify(main, null, 2) + '\n');
fs.unlinkSync(process.argv[2]);
console.log('  Caveman config merged.');
" $opencodeJsonc $cavemanJson
}

# ── 5. Set up persistent browser profile ────────────────────────
Write-Host ""
Write-Host "[4/7] Setting up persistent browser profile for Google searches..." -ForegroundColor Cyan
$profileDir = Join-Path $env:USERPROFILE ".cache\web-researcher"
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

Write-Host ""
Write-Host "  A browser window will open. Please:"
Write-Host "    1. Accept Google's cookies (click 'Aceitar tudo' / 'Accept all')"
Write-Host "    2. If CAPTCHA appears, solve it"
Write-Host "    3. Close the browser window when done"
Write-Host ""
Write-Host "  Opening browser..."
try {
    Start-Process -FilePath "playwright-cli" -ArgumentList "open", "--headed", "--persistent", "--profile=$profileDir", "https://www.google.com" -Wait
    Write-Host "  Profile saved to $profileDir"
} catch {
    Write-Host "  Could not open headed browser. Profile not set up." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Before your first search, run this manually:"
    Write-Host "    playwright-cli open --headed --persistent --profile=$profileDir https://www.google.com"
    Write-Host "    Accept cookies, solve CAPTCHA if shown, then close the browser."
}

# ── 6. Copy shared skill ────────────────────────────────────────
Write-Host ""
Write-Host "[5/7] Copying web-research skill to ~/.claude/skills/..." -ForegroundColor Cyan
$claudeSkillsDir = Join-Path $env:USERPROFILE ".claude\skills\web-research"
New-Item -ItemType Directory -Force -Path $claudeSkillsDir | Out-Null
Copy-Item "$ScriptDir\skills\web-research\SKILL.md" $claudeSkillsDir -Force
Write-Host "  Done."

# ── 7. Copy opencode sub-agent ──────────────────────────────────
Write-Host ""
Write-Host "[6/7] Copying web-researcher sub-agent and instructions to opencode config..." -ForegroundColor Cyan
$opencodeAgentsDir = Join-Path $env:USERPROFILE ".config\opencode\agents"
New-Item -ItemType Directory -Force -Path $opencodeAgentsDir | Out-Null
Copy-Item "$ScriptDir\opencode\agents\web-researcher.md" $opencodeAgentsDir -Force
Copy-Item "$ScriptDir\opencode\instructions\web-research-instructions.md" (Join-Path $env:USERPROFILE ".config\opencode\web-research-instructions.md") -Force
Write-Host "  Done."

# ── 8. Merge config patch ───────────────────────────────────────
Write-Host ""
Write-Host "[7/7] Merging config into opencode.jsonc..." -ForegroundColor Cyan

$configFile = Join-Path $env:USERPROFILE ".config\opencode\opencode.jsonc"
$patchFile = "$ScriptDir\opencode\config-patch.jsonc"

if (-not (Test-Path $configFile)) {
    '{ "$schema": "https://opencode.ai/config.json" }' | Out-File -FilePath $configFile -Encoding utf8
}

$mergeScript = [System.IO.Path]::GetTempFileName() + ".js"
@"
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
"@ | Out-File -FilePath $mergeScript -Encoding utf8

node $mergeScript $configFile $patchFile
Remove-Item $mergeScript

Write-Host ""
Write-Host "web-researcher installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Components installed:"
Write-Host "  - @playwright/cli (real browser automation)"
Write-Host "  - caveman skill (token compression for sub-agent output)"
Write-Host "  - web-research skill (shared: opencode + Claude Code)"
Write-Host "  - web-research instructions (delegation rules for plan/build agents)"
Write-Host "  - web-researcher sub-agent (opencode, model: opencode-go/deepseek-v4-flash)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart opencode (if running)"
Write-Host "  2. Restart Claude Code (if running)"
Write-Host "  3. Ask either tool to fetch a webpage."
