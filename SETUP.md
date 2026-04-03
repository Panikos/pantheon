# Pantheon Setup Guide

Complete step-by-step installation and configuration.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- `git` installed
- `gh` (GitHub CLI) installed and authenticated (`gh auth login`)
- Bash shell (Git Bash on Windows)

## Installation

### Option A: Automated (recommended)

```bash
git clone https://github.com/Panikos/pantheon.git
cd pantheon
chmod +x install.sh
./install.sh
```

This installs:
- 5 skills to `~/.claude/commands/` (pantheon, argos, morpheus, athena, hermes)
- 2 hooks to `~/.claude/hooks/` (argos-precheck.sh, pantheon-notify.sh)
- Creates `~/.claude/notifications/` directory
- Appends Pantheon section to `~/.claude/CLAUDE.md`
- Prints the settings.json hook you need to add manually

### Option B: Manual

```bash
# Skills
cp skills/*.md ~/.claude/commands/

# Session hooks go to ~/.claude/ (referenced directly by settings.json)
cp hooks/pantheon_hook.sh ~/.claude/
cp hooks/pantheon_stop_hook.sh ~/.claude/
chmod +x ~/.claude/pantheon_hook.sh ~/.claude/pantheon_stop_hook.sh

# Utility hooks go to ~/.claude/hooks/
mkdir -p ~/.claude/hooks
cp hooks/argos-precheck.sh ~/.claude/hooks/
cp hooks/pantheon-notify.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/argos-precheck.sh ~/.claude/hooks/pantheon-notify.sh

# Notifications directory
mkdir -p ~/.claude/notifications
```

Then follow the manual configuration steps below.

## Configuration

### Step 1: Add the startup hook to settings.json

The installer copies `pantheon_hook.sh` and `pantheon_stop_hook.sh` to `~/.claude/`. Then add this to your `~/.claude/settings.json` hooks section:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "bash \"$HOME/.claude/pantheon_hook.sh\"", "timeout": 3000}
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "bash \"$HOME/.claude/pantheon_stop_hook.sh\"", "timeout": 3000}
        ]
      }
    ]
  }
}
```

**Startup hook** (`pantheon_hook.sh`):
- Checks `~/.claude/pantheon_disabled` (global) — skips if present
- 30-minute cooldown via project-scoped `autostart_fired` — prevents repeated nagging
- Checks for remote commits (git fetch + ahead count) — warns if remote Argos pushed while away
- If Argos schedule is active: quiet `[PANTHEON]` confirmation
- If no schedule: `[PANTHEON-AUTOSTART]` directive telling Claude to auto-start immediately
- Reads preferred interval from project-scoped `schedule_meta.json`

**Stop hook** (`pantheon_stop_hook.sh`):
- If remote deploy is active AND local commits are unpushed: warns user to push before closing

### Step 2: Add startup behavior to CLAUDE.md

If the installer didn't already add it, append this to `~/.claude/CLAUDE.md`:

```markdown
### Pantheon Startup Behavior
A `UserPromptSubmit` hook checks for an active Argos schedule on session start. When you see a `[PANTHEON-AUTOSTART]` hook message, you MUST:
1. Immediately create a durable CronCreate schedule for Argos (read interval from ~/.claude/pantheon_schedule_meta.json or default 10m)
2. Announce: "Pantheon started: Argos monitoring every [interval]." — one line, not a question
3. Continue with the user's original request

Do NOT ask permission. If ~/.claude/pantheon_disabled exists, skip auto-start silently.

Do NOT silently ignore `[PANTHEON-AUTOSTART]` messages. Always surface them to the user.
```

**Why this is needed:** The hook message goes to Claude as a directive. Claude MUST auto-start Pantheon (not ask), announce it, and continue with the user's request. The opt-out file `~/.claude/pantheon_disabled` prevents auto-start for users who don't want it.

### Step 3: Verify installation

Open Claude Code and run:

```
/pantheon status
```

You should see the status of all agents (all inactive on first run).

## Starting the Agents

### Tier 1: Local daemon (while terminal is open)

```
/pantheon start 10m
```

This creates a durable cron job that:
1. Fires every 10 minutes while the REPL is idle
2. Runs `argos-precheck.sh` first (lightweight bash check, ~1 second)
3. If something changed: invokes Argos for full evaluation
4. If nothing changed: skips (no API cost)

**Note:** Local cron jobs auto-expire after 7 days. Run `/pantheon renew` before expiry.

### Tier 2: Cloud daemon (always-on, even terminal closed)

```
/pantheon deploy
```

This creates a remote trigger in Anthropic's cloud that:
1. Runs every 1-2 hours (minimum 1 hour interval)
2. Gets a fresh git checkout of your repository
3. Runs a self-contained Argos evaluation
4. Commits fixes and pushes to the repo
5. Continues running even when your terminal is closed

**Manage remote triggers at:** https://claude.ai/code/scheduled

### Both tiers together

For maximum coverage, run both:

```
/pantheon start 10m     # Local: fast, context-rich, every 10 min
/pantheon deploy        # Remote: persistent, every 1-2h, always-on
```

## How It Works

### On session start:
1. `UserPromptSubmit` hook fires on your first message
2. Hook checks `~/.claude/scheduled_tasks.json` for active Argos cron
3. If active: quiet confirmation
4. If inactive: Claude asks you if you want to start

### Every 10 minutes (Tier 1):
1. CronCreate fires (only while REPL is idle)
2. `argos-precheck.sh` runs (~1 second bash checks)
3. If nothing changed: tick skipped, no cost
4. If something changed: full Argos evaluation
5. Argos acts on highest priority item (P0-P6)
6. Logs action to `logs/YYYY/MM/YYYY-MM-DD.md`
7. Sends notification if P0/P1 severity

### Every 1-2 hours (Tier 2):
1. RemoteTrigger fires in Anthropic's cloud
2. Fresh git checkout, self-contained Argos prompt
3. Tests, PRs, issues, tech debt, docs evaluated
4. Fixes committed and pushed to repo

### Memory consolidation (Morpheus):
1. Triggered by Argos as a P5 action when memory is stale (>24h)
2. Also triggered manually via `/morpheus` or `/pantheon dream`
3. Four phases: orient, gather signal, consolidate, prune
4. Resets session counter after completion

## Files Created

| File | Location | Purpose |
|------|----------|---------|
| `pantheon.md` | `~/.claude/commands/` | Orchestrator skill |
| `argos.md` | `~/.claude/commands/` | Daemon skill |
| `morpheus.md` | `~/.claude/commands/` | Memory consolidation skill |
| `athena.md` | `~/.claude/commands/` | Deep planning skill |
| `argos-precheck.sh` | `~/.claude/hooks/` | Pre-check gate script |
| `pantheon-notify.sh` | `~/.claude/hooks/` | Notification script |
| `notifications/current.json` | `~/.claude/` | Latest notification (for watchers) |
| `notifications/history.jsonl` | `~/.claude/` | Notification audit log |
| `pantheon_hook.sh` | `~/.claude/` | Startup hook script (referenced by settings.json) |
| `pantheon_stop_hook.sh` | `~/.claude/` | Stop hook script (warns about unpushed commits) |
| `pantheon/autostart_fired` | `~/.claude/projects/<ID>/` | 30-min cooldown (project-scoped) |
| `pantheon/schedule_meta.json` | `~/.claude/projects/<ID>/` | Interval preference (project-scoped) |
| `pantheon/session_count` | `~/.claude/projects/<ID>/` | Session counter for Morpheus (project-scoped) |
| `pantheon/hermes_manifest.json` | `~/.claude/projects/<ID>/` | Hermes task state for cross-session resume |
| `scheduled_tasks.json` | `~/.claude/` | Durable cron schedules (auto-created) |
| `logs/YYYY/MM/YYYY-MM-DD.md` | Project root | Argos daily activity logs |

## Using Hermes (parallel coordinator)

Hermes dispatches parallel workers for large tasks. If a session closes mid-task:

1. Worker worktree branches survive (git branches persist)
2. The task manifest persists at the project-scoped path
3. Next session: run `/hermes continue` to resume
4. Hermes re-reads the manifest, checks which workers completed, re-dispatches pending ones

## Troubleshooting

### "No scheduled jobs" after restart
Local cron jobs are session-scoped by default. Use `durable: true` (Pantheon does this automatically) to persist across restarts. If they still disappear, the 7-day auto-expiry may have triggered — run `/pantheon start 10m` again.

### Hook doesn't fire on session start
- Verify the hook is in `~/.claude/settings.json` under `hooks.UserPromptSubmit`
- Verify `~/.claude/pantheon_hook.sh` exists and is executable
- The hook has a 30-minute cooldown — delete `~/.claude/pantheon_autostart_fired` to force a re-check

### Argos runs but does nothing
- Check `argos-precheck.sh` is executable: `chmod +x ~/.claude/hooks/argos-precheck.sh`
- Run it manually to see output: `bash ~/.claude/hooks/argos-precheck.sh`
- If it always returns `{"changed": false}`, your project may genuinely have no work to do

### Remote trigger not firing
- Check status at https://claude.ai/code/scheduled
- Minimum interval is 1 hour
- The trigger needs access to your GitHub repo (must be the repo URL you provided)

## Uninstall

```bash
./install.sh --uninstall
```

This removes skill and hook files. You must manually remove:
- The `UserPromptSubmit` hook from `~/.claude/settings.json`
- The Pantheon section from `~/.claude/CLAUDE.md`
- Remote triggers at https://claude.ai/code/scheduled
