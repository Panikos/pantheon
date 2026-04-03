#!/usr/bin/env bash
# argos-precheck.sh — Lightweight gate that checks if anything changed
# before invoking a full Argos API call. Saves ~80% of wasted ticks.
#
# Returns via stdout JSON:
#   {"changed": true, "signals": [...]}  — something needs attention
#   {"changed": false}                   — skip this tick
#
# Usage: Called by Pantheon/Argos before full evaluation.
#   result=$(bash ~/.claude/hooks/argos-precheck.sh)
#   if echo "$result" | grep -q '"changed": true'; then ... fi

set -e

SIGNALS=()
CHANGED=false

# 1. Git: any uncommitted changes or recent commits?
if git rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    SIGNALS+=("uncommitted_changes")
    CHANGED=true
  fi
  RECENT=$(git log --oneline --since="15 minutes ago" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$RECENT" -gt 0 ]; then
    SIGNALS+=("recent_commits:$RECENT")
    CHANGED=true
  fi
fi

# 2. GitHub: any open PRs or issues updated recently?
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  OPEN_PRS=$(gh pr list --state open --json number --limit 1 2>/dev/null | grep -c "number" || true)
  if [ "$OPEN_PRS" -gt 0 ]; then
    SIGNALS+=("open_prs")
    CHANGED=true
  fi
fi

# 3. Tests: quick check if test suite exists and last run had failures
# (check for common test result files)
for f in test-results.xml .pytest_cache/lastfailed coverage/lcov.info; do
  if [ -f "$f" ]; then
    if [ "$f" = ".pytest_cache/lastfailed" ] && [ -s "$f" ]; then
      SIGNALS+=("failing_tests")
      CHANGED=true
    fi
  fi
done

# 4. TECH_DEBT.md: any open items?
if [ -f "TECH_DEBT.md" ] && grep -qi "open\|deferred" "TECH_DEBT.md" 2>/dev/null; then
  SIGNALS+=("open_tech_debt")
  CHANGED=true
fi

# 5. Morpheus: memory stale? (>24h since last dream)
MEMORY_INDEX="$HOME/.claude/projects/$(pwd | sed 's|/|--|g' | sed 's|:||g')/memory/MEMORY.md"
if [ -f "$MEMORY_INDEX" ]; then
  LAST_DREAM=$(grep -o 'Last dream: [0-9-]*' "$MEMORY_INDEX" 2>/dev/null | head -1 | cut -d' ' -f3)
  if [ -n "$LAST_DREAM" ]; then
    DREAM_TS=$(date -d "$LAST_DREAM" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DIFF=$(( (NOW_TS - DREAM_TS) / 3600 ))
    if [ "$DIFF" -gt 24 ]; then
      SIGNALS+=("memory_stale:${DIFF}h")
      CHANGED=true
    fi
  fi
fi

# Output
if $CHANGED; then
  SIG_JSON=$(printf '"%s",' "${SIGNALS[@]}" | sed 's/,$//')
  echo "{\"changed\": true, \"signals\": [$SIG_JSON]}"
else
  echo "{\"changed\": false}"
fi
