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

# 3. Argos already scheduled? → brief info, no action needed
if [ -f "$SCHEDULE_FILE" ] && grep -q "argos" "$SCHEDULE_FILE" 2>/dev/null; then
  echo '{"result":"pass","message":"[PANTHEON] Argos schedule is active."}'
  exit 0
fi

# 4. No Argos schedule → request AUTOSTART
INTERVAL="10m"
if [ -f "$META_FILE" ]; then
  SAVED=$(grep -o '"interval":"[^"]*"' "$META_FILE" 2>/dev/null | cut -d'"' -f4)
  [ -n "$SAVED" ] && INTERVAL="$SAVED"
fi

cat <<EOF
{"result":"pass","message":"[PANTHEON-AUTOSTART] No active Argos schedule. Immediately run /pantheon start ${INTERVAL} — do NOT ask the user, just start it and announce: Pantheon started: Argos monitoring every ${INTERVAL}. Then continue with their request."}
EOF
