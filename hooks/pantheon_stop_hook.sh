#!/bin/bash
# pantheon_stop_hook.sh — Warns on session exit if remote deploy is active
# and there are unpushed local commits.
# Registered as a Stop hook in settings.json.

CLAUDE_DIR="$HOME/.claude"
META_FILE="$CLAUDE_DIR/pantheon_schedule_meta.json"

silent_pass() {
  echo '{"result":"pass"}'
  exit 0
}

# Only warn if we're in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || silent_pass

# Check for unpushed commits
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
[ "$AHEAD" -eq 0 ] && silent_pass

# Check if a remote trigger exists (we can't call RemoteTrigger from bash,
# so check for the meta file + a marker that deploy was used)
DEPLOY_MARKER="$CLAUDE_DIR/pantheon_deploy_active"
[ -f "$DEPLOY_MARKER" ] || silent_pass

# Unpushed commits + remote deploy active → warn
echo "{\"result\":\"pass\",\"message\":\"[PANTHEON] Warning: You have ${AHEAD} unpushed commit(s) and a remote Argos deploy is active. Remote Argos is working on older code. Consider running git push before closing.\"}"
