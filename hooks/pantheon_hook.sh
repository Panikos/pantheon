#!/bin/bash
# pantheon_hook.sh — Pantheon startup check for UserPromptSubmit hook
# Fires once per session (~30 min window), then stays silent.

CLAUDE_DIR="$HOME/.claude"
DISABLED_FILE="$CLAUDE_DIR/pantheon_disabled"
FIRED_FILE="$CLAUDE_DIR/pantheon_autostart_fired"
SCHEDULE_FILE="$CLAUDE_DIR/scheduled_tasks.json"
META_FILE="$CLAUDE_DIR/pantheon_schedule_meta.json"

silent_pass() {
  echo '{"result":"pass"}'
  exit 0
}

# 1. Disabled? → always silent
[ -f "$DISABLED_FILE" ] && silent_pass

# 2. Already fired in the last 30 minutes? → silent (prevents repeated nagging)
if [ -f "$FIRED_FILE" ]; then
  STALE=$(find "$FIRED_FILE" -mmin +30 2>/dev/null)
  [ -z "$STALE" ] && silent_pass
fi

# First meaningful fire this session — mark it
touch "$FIRED_FILE"

# 3. Check if remote deploy pushed commits while we were away
REMOTE_WARN=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch --quiet 2>/dev/null
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  if [ "$BEHIND" -gt 0 ]; then
    REMOTE_WARN=" Remote Argos pushed ${BEHIND} commit(s) while you were away — run git pull to sync."
  fi
fi

# 4. Argos already scheduled? → brief info + remote warning if any
if [ -f "$SCHEDULE_FILE" ] && grep -q "argos" "$SCHEDULE_FILE" 2>/dev/null; then
  if [ -n "$REMOTE_WARN" ]; then
    echo "{\"result\":\"pass\",\"message\":\"[PANTHEON] Argos schedule is active.${REMOTE_WARN}\"}"
  else
    echo '{"result":"pass","message":"[PANTHEON] Argos schedule is active."}'
  fi
  exit 0
fi

# 4. No Argos schedule → request AUTOSTART
INTERVAL="10m"
if [ -f "$META_FILE" ]; then
  SAVED=$(grep -o '"interval":"[^"]*"' "$META_FILE" 2>/dev/null | cut -d'"' -f4)
  [ -n "$SAVED" ] && INTERVAL="$SAVED"
fi

cat <<EOF
{"result":"pass","message":"[PANTHEON-AUTOSTART] No active Argos schedule. Immediately run /pantheon start ${INTERVAL} — do NOT ask the user, just start it and announce: Pantheon started: Argos monitoring every ${INTERVAL}.${REMOTE_WARN} Then continue with their request."}
EOF
