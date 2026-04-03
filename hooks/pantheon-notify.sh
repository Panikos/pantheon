#!/usr/bin/env bash
# pantheon-notify.sh — Write notifications to an external file
# that Duskit or other watchers can pick up.
#
# Usage:
#   bash ~/.claude/hooks/pantheon-notify.sh "ARGOS" "P0" "Failing tests detected in src/api"
#   bash ~/.claude/hooks/pantheon-notify.sh "MORPHEUS" "INFO" "Memory consolidated: 12 files, 3 merged"
#
# Notifications are written to:
#   ~/.claude/notifications/current.json  (latest notification, overwritten)
#   ~/.claude/notifications/history.jsonl (append-only log)

set -e

SOURCE="${1:-PANTHEON}"
SEVERITY="${2:-INFO}"
MESSAGE="${3:-No message}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOCAL_TIME=$(date +"%H:%M")

NOTIFY_DIR="$HOME/.claude/notifications"
mkdir -p "$NOTIFY_DIR"

# Build notification JSON
# Escape message for JSON (pure bash — no jq or python dependency)
ESCAPED_MSG=$(echo "$MESSAGE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
NOTIFICATION="{\"ts\":\"$TIMESTAMP\",\"source\":\"$SOURCE\",\"severity\":\"$SEVERITY\",\"message\":\"$ESCAPED_MSG\",\"local_time\":\"$LOCAL_TIME\"}"

# Write current (latest) notification — Duskit and other watchers read this
echo "$NOTIFICATION" > "$NOTIFY_DIR/current.json"

# Append to history log
echo "$NOTIFICATION" >> "$NOTIFY_DIR/history.jsonl"

# Windows toast notification (if powershell available)
if command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
  PS_CMD="powershell -Command \"[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.BalloonTipTitle = 'Pantheon: $SOURCE'; \$n.BalloonTipText = '$MESSAGE'; \$n.Visible = \$true; \$n.ShowBalloonTip(5000); Start-Sleep -Seconds 6; \$n.Dispose()\""
  # Only show toast for P0/P1 severity
  if [ "$SEVERITY" = "P0" ] || [ "$SEVERITY" = "P1" ]; then
    eval "$PS_CMD" >/dev/null 2>&1 &
  fi
fi

echo "{\"result\": \"pass\", \"message\": \"Notification sent: [$SOURCE] $MESSAGE\"}"
