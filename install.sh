#!/usr/bin/env bash
# install.sh — Install Pantheon autonomous agent suite for Claude Code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DRY_RUN=false
SKIP_HOOKS=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --no-hooks)   SKIP_HOOKS=true ;;
    --uninstall)
      echo "Removing Pantheon files..."
      rm -f "$CLAUDE_HOME/commands/pantheon.md" \
            "$CLAUDE_HOME/commands/argos.md" \
            "$CLAUDE_HOME/commands/morpheus.md" \
            "$CLAUDE_HOME/commands/athena.md" \
            "$CLAUDE_HOME/commands/hermes.md" \
            "$CLAUDE_HOME/hooks/argos-precheck.sh" \
            "$CLAUDE_HOME/hooks/pantheon-notify.sh"
      echo "Removed skill and hook files."
      echo "NOTE: You must manually remove the UserPromptSubmit hook"
      echo "  from ~/.claude/settings.json and the Startup Behavior"
      echo "  section from ~/.claude/CLAUDE.md if you added them."
      exit 0
      ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Installs Pantheon autonomous agent suite into ~/.claude/"
      echo ""
      echo "Options:"
      echo "  --dry-run      Show what would be installed without changes"
      echo "  --no-hooks     Skip settings.json and CLAUDE.md modifications"
      echo "  --uninstall    Remove Pantheon files"
      echo "  --help         Show this help"
      exit 0
      ;;
  esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC}  $1"; }

# Pre-flight
if [ ! -d "$CLAUDE_HOME" ]; then
  err "~/.claude/ not found. Install Claude Code first."
  exit 1
fi

echo ""
echo -e "${BOLD}=== Pantheon — Autonomous Agent Suite ===${NC}"
echo ""
echo "  Target: $CLAUDE_HOME"
$DRY_RUN && echo -e "  Mode:   ${YELLOW}DRY RUN${NC}"
echo ""

INSTALLED=0

# ─── 1. Install skills ───────────────────────────────────────
info "Installing skills to ~/.claude/commands/..."
mkdir -p "$CLAUDE_HOME/commands"
for f in "$SCRIPT_DIR/skills/"*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  dst="$CLAUDE_HOME/commands/$bn"
  if $DRY_RUN; then
    [ -f "$dst" ] && echo "  [DRY] Would overwrite: $dst" || echo "  [DRY] Would install: $dst"
  else
    [ -f "$dst" ] && warn "Overwriting: $bn"
    cp "$f" "$dst"
    ok "$bn"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# ─── 2. Install hooks ────────────────────────────────────────
info "Installing hooks..."
mkdir -p "$CLAUDE_HOME/hooks"

# pantheon_hook.sh and pantheon_stop_hook.sh go to ~/.claude/ (referenced directly by settings.json)
for hookfile in pantheon_hook.sh pantheon_stop_hook.sh; do
  if [ -f "$SCRIPT_DIR/hooks/$hookfile" ]; then
    dst="$CLAUDE_HOME/$hookfile"
    if $DRY_RUN; then
      [ -f "$dst" ] && echo "  [DRY] Would overwrite: $dst" || echo "  [DRY] Would install: $dst"
    else
      [ -f "$dst" ] && warn "Overwriting: $hookfile"
      cp "$SCRIPT_DIR/hooks/$hookfile" "$dst"
      chmod +x "$dst" 2>/dev/null || true
      ok "$hookfile -> ~/.claude/"
      INSTALLED=$((INSTALLED + 1))
    fi
  fi
done

# Other hooks go to ~/.claude/hooks/
for f in "$SCRIPT_DIR/hooks/"*.sh; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  [ "$bn" = "pantheon_hook.sh" ] && continue      # already handled above
  [ "$bn" = "pantheon_stop_hook.sh" ] && continue  # already handled above
  dst="$CLAUDE_HOME/hooks/$bn"
  if $DRY_RUN; then
    [ -f "$dst" ] && echo "  [DRY] Would overwrite: $dst" || echo "  [DRY] Would install: $dst"
  else
    [ -f "$dst" ] && warn "Overwriting: $bn"
    cp "$f" "$dst"
    chmod +x "$dst" 2>/dev/null || true
    ok "$bn"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# ─── 3. Create directories ───────────────────────────────────
if ! $DRY_RUN; then
  mkdir -p "$CLAUDE_HOME/notifications"
  ok "Created: ~/.claude/notifications/"
fi

# ─── 4. Configure settings.json hook ─────────────────────────
if ! $SKIP_HOOKS; then
  info "Configuring startup hook in settings.json..."
  SETTINGS="$CLAUDE_HOME/settings.json"

  if [ -f "$SETTINGS" ]; then
    # Check if hook already exists
    if grep -q "pantheon_hook" "$SETTINGS" 2>/dev/null || grep -q "PANTHEON-AUTOSTART" "$SETTINGS" 2>/dev/null; then
      if $DRY_RUN; then
        echo "  [DRY] Startup hook already present in settings.json"
      else
        ok "Startup hook already present in settings.json"
      fi
    else
      if $DRY_RUN; then
        echo "  [DRY] Would add UserPromptSubmit hook to settings.json"
        echo ""
        warn "Manual step required (--dry-run prevents auto-edit):"
        echo "  Add the following to your settings.json 'hooks' section."
        echo "  See README.md section '3b. Auto-start on session resume'"
      else
        warn "Cannot auto-edit settings.json safely (complex JSON merge)."
        echo ""
        echo -e "  ${YELLOW}MANUAL STEP:${NC} Add this to your ~/.claude/settings.json:"
        echo ""
        echo '  "hooks": {'
        echo '    "UserPromptSubmit": ['
        echo '      {'
        echo '        "matcher": "",'
        echo '        "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/pantheon_hook.sh\"", "timeout": 3000}]'
        echo '      }'
        echo '    ],'
        echo '    "Stop": ['
        echo '      {'
        echo '        "matcher": "",'
        echo '        "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/pantheon_stop_hook.sh\"", "timeout": 3000}]'
        echo '      }'
        echo '    ]'
        echo '  }'
        echo ""
      fi
    fi
  else
    warn "No settings.json found. Skipping hook setup."
    echo "  Create one or add the hook manually. See README.md."
  fi

  # ─── 5. Configure CLAUDE.md startup behavior ─────────────────
  info "Configuring startup behavior in CLAUDE.md..."
  CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"

  if [ -f "$CLAUDE_MD" ]; then
    if grep -q "PANTHEON-AUTOSTART" "$CLAUDE_MD" 2>/dev/null; then
      if $DRY_RUN; then
        echo "  [DRY] Startup behavior already present in CLAUDE.md"
      else
        ok "Startup behavior already present in CLAUDE.md"
      fi
    else
      PANTHEON_BLOCK='
---

## AUTONOMOUS AGENTS (Pantheon Suite)

### Startup Behavior
A `UserPromptSubmit` hook checks for an active Argos schedule on session start. When you see a `[PANTHEON-AUTOSTART]` hook message, you MUST:
1. Immediately create a durable CronCreate schedule for Argos (default: every 10 minutes)
2. Read `~/.claude/pantheon_schedule_meta.json` if it exists — use the stored interval preference instead of the default
3. Announce to the user: "Pantheon started: Argos monitoring every [interval]." — one line, not a question
4. Then continue with the user'"'"'s original request

Do NOT ask the user for permission. Do NOT silently ignore the message. Start the schedule, announce it, move on.

If the file `~/.claude/pantheon_disabled` exists, skip auto-start entirely and say nothing.

When you see a `[PANTHEON]` message (schedule already active), say nothing — it is informational.

### /pantheon — Orchestrator & Control Plane
- `/pantheon start 10m` — schedule Argos on recurring cron (durable, survives restarts)
- `/pantheon stop` — cancel all scheduled agents
- `/pantheon status` — show state of all agents
- `/pantheon deploy` — create always-on cloud daemon (survives terminal close)

### /argos — Autonomous Daemon Agent
Decide-act-sleep loop. Priority ladder: P0 broken -> P1 signals -> P2 backlog -> P3 docs -> P4 quality -> P5 proactive -> P6 all clear.

### /morpheus — Memory Consolidation
Four-phase: Orient -> Gather Signal -> Consolidate -> Prune.

### /athena — Deep Strategic Planning
Problem decomposition -> 3+ options with trade-off matrix -> implementation blueprint.

### /hermes — Parallel Work Coordinator
Decomposes tasks into subtasks, dispatches parallel workers, reconciles results. Cross-session via manifest.'

      if $DRY_RUN; then
        echo "  [DRY] Would append Pantheon section to CLAUDE.md"
      else
        echo "$PANTHEON_BLOCK" >> "$CLAUDE_MD"
        ok "Appended Pantheon section to CLAUDE.md"
        INSTALLED=$((INSTALLED + 1))
      fi
    fi
  else
    if $DRY_RUN; then
      echo "  [DRY] Would create CLAUDE.md with Pantheon section"
    else
      echo "$PANTHEON_BLOCK" > "$CLAUDE_MD"
      ok "Created CLAUDE.md with Pantheon section"
      INSTALLED=$((INSTALLED + 1))
    fi
  fi
fi

# ─── Summary ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Installation Complete ---${NC}"
if $DRY_RUN; then
  echo "  Dry run. No changes made."
else
  echo "  Installed: $INSTALLED files"
  echo ""
  echo -e "  ${BOLD}Skills:${NC}"
  echo "    /pantheon  — orchestrator and control plane"
  echo "    /argos     — autonomous daemon (decide-act-sleep)"
  echo "    /morpheus  — memory consolidation"
  echo "    /athena    — deep strategic planning"
  echo "    /hermes    — parallel work coordinator"
  echo ""
  echo -e "  ${BOLD}Hooks:${NC}"
  echo "    argos-precheck.sh    — pre-check gate (saves ~80% API cost)"
  echo "    pantheon-notify.sh   — notifications (file + Windows toast)"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo "    1. Add the UserPromptSubmit hook to settings.json (see above)"
  echo "    2. Open Claude Code in any project"
  echo "    3. Run: /pantheon start 10m"
  echo "    4. (Optional) Run: /pantheon deploy — for always-on cloud daemon"
  echo ""
  echo -e "  ${BOLD}Manage at:${NC} https://claude.ai/code/scheduled"
fi
echo ""
