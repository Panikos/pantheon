#!/bin/bash
# pantheon_hook.sh — Pantheon startup hook for SessionStart
# Fires when session begins or resumes. Output becomes Claude's context.
# No jq dependency — pure bash.

CLAUDE_DIR="$HOME/.claude"

# Global controls
DISABLED_FILE="$CLAUDE_DIR/pantheon_disabled"

# Project-scoped state (matches Claude Code's project path pattern)
PROJECT_ID=$(pwd | sed 's|^/c/|C--|' | sed 's|^/[A-Za-z]/|/|' | sed 's|^/||' | sed 's|/|-|g')
PANTHEON_DIR="$CLAUDE_DIR/projects/$PROJECT_ID/pantheon"
mkdir -p "$PANTHEON_DIR" 2>/dev/null

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

# 1. Disabled globally? → no context needed
if [ -f "$DISABLED_FILE" ]; then
  exit 0
fi

# 2. Check if remote deploy pushed commits while we were away
REMOTE_WARN=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch --quiet 2>/dev/null
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  if [ "$BEHIND" -gt 0 ]; then
    REMOTE_WARN="REMOTE SYNC WARNING: Remote Argos pushed ${BEHIND} commit(s) while you were away. Run git pull to sync before making changes."
  fi
fi

# 3. Read interval preference
INTERVAL="10m"
if [ -f "$META_FILE" ]; then
  SAVED=$(grep -o '"interval":"[^"]*"' "$META_FILE" 2>/dev/null | cut -d'"' -f4)
  [ -n "$SAVED" ] && INTERVAL="$SAVED"
fi

# 4. Check if Argos is already scheduled
if [ -f "$SCHEDULE_FILE" ] && grep -q "argos" "$SCHEDULE_FILE" 2>/dev/null; then
  # Already scheduled — just add remote warning if any
  if [ -n "$REMOTE_WARN" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[PANTHEON] Argos schedule is active. ${REMOTE_WARN}"}}
EOF
  fi
  exit 0
fi

# 5. No Argos schedule + auto-start enabled → inject autostart context
CONTEXT="[PANTHEON-AUTOSTART] No active Argos schedule detected. You MUST immediately create a durable CronCreate schedule: cron='*/10 * * * *', prompt='First run the pre-check gate: bash ~/.claude/hooks/argos-precheck.sh. If the result contains changed false, respond with nothing. If changed true, run /argos — one full evaluation cycle. Act on the highest priority item found. Use bash ~/.claude/hooks/pantheon-notify.sh ARGOS P0 description to send notifications for P0/P1 actions. Log to append-only daily file.', durable=true, recurring=true. Then announce to the user: Pantheon started: Argos monitoring every ${INTERVAL}. Do this BEFORE processing any user request."

if [ -n "$REMOTE_WARN" ]; then
  CONTEXT="${CONTEXT} ${REMOTE_WARN}"
fi

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${CONTEXT}"}}
EOF
