#!/bin/bash
# pantheon_hook.sh — Pantheon startup check for UserPromptSubmit hook
# State is project-scoped; disable/deploy are global.
# No jq dependency — pure bash.

CLAUDE_DIR="$HOME/.claude"

# Global controls
DISABLED_FILE="$CLAUDE_DIR/pantheon_disabled"

# Project-scoped state (matches Claude Code's project path pattern)
PROJECT_ID=$(pwd | sed 's|^/c/|C--|' | sed 's|^/[A-Za-z]/|/|' | sed 's|^/||' | sed 's|/|-|g')
PANTHEON_DIR="$CLAUDE_DIR/projects/$PROJECT_ID/pantheon"
mkdir -p "$PANTHEON_DIR" 2>/dev/null

FIRED_FILE="$PANTHEON_DIR/autostart_fired"
META_FILE="$PANTHEON_DIR/schedule_meta.json"
COUNT_FILE="$PANTHEON_DIR/session_count"
SCHEDULE_FILE="$CLAUDE_DIR/scheduled_tasks.json"

# Increment session counter (project-scoped)
if [ -f "$COUNT_FILE" ]; then
  COUNT=$(cat "$COUNT_FILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo $COUNT > "$COUNT_FILE"

silent_pass() {
  echo '{"result":"pass"}'
  exit 0
}

# 1. Disabled globally? → always silent
[ -f "$DISABLED_FILE" ] && silent_pass

# 2. Check if remote deploy pushed commits while we were away
REMOTE_WARN=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch --quiet 2>/dev/null
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  if [ "$BEHIND" -gt 0 ]; then
    REMOTE_WARN=" Remote Argos pushed ${BEHIND} commit(s) while you were away — run git pull to sync."
  fi
fi

# 3. Argos already scheduled? → brief info (no cooldown needed — this is harmless)
if [ -f "$SCHEDULE_FILE" ] && grep -q "argos" "$SCHEDULE_FILE" 2>/dev/null; then
  if [ -n "$REMOTE_WARN" ]; then
    echo "{\"result\":\"pass\",\"message\":\"[PANTHEON] Argos schedule is active.${REMOTE_WARN}\"}"
  else
    # Already active, nothing to report — stay silent
    silent_pass
  fi
  exit 0
fi

# 4. No Argos schedule — check cooldown before requesting autostart
#    Cooldown prevents nagging on every message within same session
if [ -f "$FIRED_FILE" ]; then
  STALE=$(find "$FIRED_FILE" -mmin +30 2>/dev/null)
  [ -z "$STALE" ] && silent_pass
fi

# First autostart fire for this project this session — mark it
touch "$FIRED_FILE"

# 5. Read interval preference
INTERVAL="10m"
if [ -f "$META_FILE" ]; then
  SAVED=$(grep -o '"interval":"[^"]*"' "$META_FILE" 2>/dev/null | cut -d'"' -f4)
  [ -n "$SAVED" ] && INTERVAL="$SAVED"
elif [ -f "$CLAUDE_DIR/pantheon_schedule_meta.json" ]; then
  SAVED=$(grep -o '"interval":"[^"]*"' "$CLAUDE_DIR/pantheon_schedule_meta.json" 2>/dev/null | cut -d'"' -f4)
  [ -n "$SAVED" ] && INTERVAL="$SAVED"
fi

# 6. Request autostart
cat <<EOF
{"result":"pass","message":"[PANTHEON-AUTOSTART] No active Argos schedule. Immediately run /pantheon start ${INTERVAL} — do NOT ask the user, just start it and announce: Pantheon started: Argos monitoring every ${INTERVAL}.${REMOTE_WARN} Then continue with their request."}
EOF
