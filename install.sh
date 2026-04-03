#!/usr/bin/env bash
# install.sh — Install Pantheon autonomous agent suite for Claude Code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--dry-run]"
      echo ""
      echo "Installs Pantheon skills and hooks into ~/.claude/"
      echo "  --dry-run    Show what would be installed without making changes"
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

# Install skills
info "Installing skills..."
mkdir -p "$CLAUDE_HOME/commands"
for f in "$SCRIPT_DIR/skills/"*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  dst="$CLAUDE_HOME/commands/$bn"
  if $DRY_RUN; then
    [ -f "$dst" ] && echo "  [DRY] Would overwrite: $dst" || echo "  [DRY] Would install: $dst"
  else
    if [ -f "$dst" ]; then
      warn "Exists: $dst (overwriting)"
    fi
    cp "$f" "$dst"
    ok "Installed: $bn"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# Install hooks
info "Installing hooks..."
mkdir -p "$CLAUDE_HOME/hooks"
for f in "$SCRIPT_DIR/hooks/"*.sh; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  dst="$CLAUDE_HOME/hooks/$bn"
  if $DRY_RUN; then
    [ -f "$dst" ] && echo "  [DRY] Would overwrite: $dst" || echo "  [DRY] Would install: $dst"
  else
    if [ -f "$dst" ]; then
      warn "Exists: $dst (overwriting)"
    fi
    cp "$f" "$dst"
    chmod +x "$dst" 2>/dev/null || true
    ok "Installed: $bn"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# Create notifications directory
if ! $DRY_RUN; then
  mkdir -p "$CLAUDE_HOME/notifications"
  ok "Created: ~/.claude/notifications/"
fi

echo ""
echo -e "${BOLD}--- Summary ---${NC}"
if $DRY_RUN; then
  echo "  Dry run. No changes made."
else
  echo "  Installed: $INSTALLED files"
  echo ""
  echo "  Next steps:"
  echo "    1. Open Claude Code in any project"
  echo "    2. Run: /pantheon start 10m"
  echo "    3. (Optional) Run: /pantheon deploy"
  echo ""
  echo "  Skills installed:"
  echo "    /pantheon  — orchestrator and control plane"
  echo "    /argos     — autonomous daemon (decide-act-sleep)"
  echo "    /morpheus  — memory consolidation"
  echo "    /athena    — deep strategic planning"
fi
echo ""
