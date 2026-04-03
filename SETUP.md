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
- 4 skills to `~/.claude/commands/` (pantheon, argos, morpheus, athena)
- 2 hooks to `~/.claude/hooks/` (argos-precheck.sh, pantheon-notify.sh)
- Creates `~/.claude/notifications/` directory
- Appends Pantheon section to `~/.claude/CLAUDE.md`
- Prints the settings.json hook you need to add manually

### Option B: Manual

```bash
# Skills
cp skills/*.md ~/.claude/commands/

# Hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/argos-precheck.sh
chmod +x ~/.claude/hooks/pantheon-notify.sh

# Notifications directory
mkdir -p ~/.claude/notifications
```

Then follow the manual configuration steps below.

## Configuration

### Step 1: Add the startup hook to settings.json

Edit `~/.claude/settings.json` and add a `hooks` section (or merge into your existing one):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'if [ ! -f \"$HOME/.claude/pantheon_checked\" ] || [ \"$(find \"$HOME/.claude/pantheon_checked\" -mmin +5 2>/dev/null)\" ]; then touch \"$HOME/.claude/pantheon_checked\"; if [ -f \"$HOME/.claude/scheduled_tasks.json\" ] && grep -q \"argos\" \"$HOME/.claude/scheduled_tasks.json\" 2>/dev/null; then echo \"{\\\"result\\\":\\\"pass\\\",\\\"message\\\":\\\"[PANTHEON] Argos schedule is active.\\\"}\"; else echo \"{\\\"result\\\":\\\"pass\\\",\\\"message\\\":\\\"[PANTHEON-AUTOSTART] No active Argos schedule. Ask the user: Pantheon autonomous monitoring is not running. Would you like me to start it? Then wait for their answer. If yes, run /pantheon start 10m. If no, acknowledge and continue.\\\"}\"; fi; else echo \"{\\\"result\\\":\\\"pass\\\"}\"; fi'",
            "timeout": 3000
          }
        ]
      }
    ]
  }
}
```

**What this does:** On each new session (5-minute cooldown), it detects whether an Argos schedule is active. If not, it instructs Claude to **auto-start Pantheon immediately** and announce it — no user permission required. Reads preferred interval from `~/.claude/pantheon_schedule_meta.json` if it exists. Respects `~/.claude/pantheon_disabled` opt-out file.

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
| `pantheon_checked` | `~/.claude/` | 24h cooldown timestamp |
| `pantheon_session_count` | `~/.claude/` | Session counter for Morpheus |
| `scheduled_tasks.json` | `~/.claude/` | Durable cron schedules (auto-created) |
| `logs/YYYY/MM/YYYY-MM-DD.md` | Project root | Argos daily activity logs |

## Troubleshooting

### "No scheduled jobs" after restart
Local cron jobs are session-scoped by default. Use `durable: true` (Pantheon does this automatically) to persist across restarts. If they still disappear, the 7-day auto-expiry may have triggered — run `/pantheon start 10m` again.

### Hook doesn't fire on session start
- Verify the hook is in `~/.claude/settings.json` under `hooks.UserPromptSubmit`
- Check that the bash command syntax is correct (escaped quotes are tricky)
- The hook has a 5-minute cooldown to avoid nagging within a session — delete `~/.claude/pantheon_checked` to force a re-check

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
