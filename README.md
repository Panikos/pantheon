# Pantheon

An open-source autonomous agent suite for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that replicates ~85% of the unreleased Kairos daemon architecture using publicly available Claude Code features.

Four agents from Greek mythology, one orchestrator:

| Agent | Named After | Role |
|-------|------------|------|
| **Pantheon** | The temple of all gods | Orchestrator and control plane |
| **Argos** | The all-seeing giant (100 eyes, never slept) | Autonomous decide-act-sleep daemon |
| **Morpheus** | God of dreams | Memory consolidation |
| **Athena** | Goddess of wisdom and strategic warfare | Deep strategic planning |

## What This Does

Pantheon turns Claude Code from a reactive tool into a **proactive background agent** that:

- Monitors your repository for broken tests, open PRs, stale docs, and tech debt
- Acts autonomously on a priority ladder (P0 broken state through P6 all clear)
- Consolidates project memory across sessions
- Produces deep strategic plans for complex problems
- Runs in two tiers: locally while your terminal is open, AND remotely in Anthropic's cloud when it's closed

## Quick Start

### 1. Install skills

```bash
git clone https://github.com/Panikos/pantheon.git
cp pantheon/skills/*.md ~/.claude/commands/
```

### 2. Install hooks

```bash
cp pantheon/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/argos-precheck.sh
chmod +x ~/.claude/hooks/pantheon-notify.sh
```

### 3. Start the local daemon

Open Claude Code in any project and run:

```
/pantheon start 10m
```

This schedules Argos to evaluate your project every 10 minutes while the REPL is open.

### 4. Deploy the cloud daemon (optional, always-on)

```
/pantheon deploy
```

This creates a remote trigger in Anthropic's cloud that runs Argos every 1-2 hours, even when your terminal is closed.

## Architecture

```
PANTHEON — Two-Tier Autonomous Agent Suite
==========================================

TIER 1 — LOCAL (while REPL is open)
  pantheon start 10m
    +-- CronCreate (durable, */10 * * * *)
         +-- argos-precheck.sh (lightweight bash gate)
              |-- changed=false --> skip tick (no API cost)
              +-- changed=true --> /argos (full evaluation)
                   |-- P0-P4: act, commit, log
                   |-- P5: /morpheus (if memory stale >24h)
                   +-- P6: sleep

TIER 2 — REMOTE (always-on cloud daemon)
  pantheon deploy
    +-- RemoteTrigger (Anthropic cloud, every 1-2h)
         +-- Self-contained Argos prompt
              |-- Run tests, fix if broken
              |-- Triage GitHub PRs and issues
              |-- Resolve tech debt
              |-- Update stale docs
              +-- Log to repo logs/
```

### How a Tick Works

```
Timer fires
  |
  v
argos-precheck.sh (bash, ~1 second)
  |-- Checks: git status, GitHub PRs, test failures,
  |   tech debt, memory staleness
  |
  |-- Nothing changed? --> SKIP (no API call, no cost)
  |
  +-- Something changed? --> Invoke Argos
        |
        v
      Argos evaluates priority ladder (P0-P6)
        |
        +-- P0 BROKEN: fix tests, commit
        +-- P1 SIGNALS: triage PRs/issues
        +-- P2 BACKLOG: resolve tech debt
        +-- P3 DOCS: update stale docs
        +-- P4 QUALITY: fix TODOs, coverage gaps
        +-- P5 PROACTIVE: run /morpheus if memory stale
        +-- P6 ALL CLEAR: log and sleep
        |
        v
      Log action to logs/YYYY/MM/YYYY-MM-DD.md
        |
        v
      Notify if P0/P1 (toast + ~/.claude/notifications/)
```

## Commands

### Pantheon (orchestrator)

| Command | Description |
|---------|-------------|
| `/pantheon start [interval]` | Start local daemon (default: 10 min) |
| `/pantheon stop` | Stop all local scheduled agents |
| `/pantheon status` | Show state of all agents |
| `/pantheon deploy [repo]` | Create always-on cloud daemon |
| `/pantheon undeploy` | Disable cloud daemon |
| `/pantheon watch` | Enable GitHub PR/issue polling (every 5 min) |
| `/pantheon renew` | Extend 7-day auto-expiry on local cron |
| `/pantheon history [days]` | Summarise Argos activity |
| `/pantheon dream` | Manually trigger Morpheus |
| `/pantheon plan [problem]` | Shortcut to Athena |

### Argos (daemon)

| Command | Description |
|---------|-------------|
| `/argos` | One evaluation cycle |
| `/argos loop` | Continuous until all clear |

### Morpheus (memory)

| Command | Description |
|---------|-------------|
| `/morpheus` | Full 4-phase consolidation |
| `/morpheus status` | Memory health check |
| `/morpheus dry-run` | Preview changes without applying |

### Athena (planning)

| Command | Description |
|---------|-------------|
| `/athena [problem]` | Start deep planning session |
| `/athena review [plan]` | Refine existing plan |
| `/athena continue` | Resume last planning session |

## Comparison to Kairos

In March 2026, Claude Code's source was [accidentally leaked](https://thehackernews.com/2026/04/claude-code-tleaked-via-npm-packaging.html) via an npm packaging error. The leak revealed three unreleased systems: **Kairos** (autonomous daemon), **autoDream** (memory consolidation), and **ULTRAPLAN** (deep planning). Pantheon replicates their architecture using publicly available Claude Code features.

| Capability | Kairos (unreleased) | Pantheon | Coverage |
|---|---|---|---|
| Autonomous daemon | Native runtime tick injection | Two-tier: local CronCreate + remote RemoteTrigger | 85% |
| Cost-saving sleep | Dedicated SleepTool yields cheaply | Pre-check bash gate skips empty ticks | 80% |
| Memory consolidation | autoDream forked sub-agent, auto-triggered | Morpheus 4-phase (orient, gather, consolidate, prune) | 90% |
| Deep planning | ULTRAPLAN remote container, 30 min think time | Athena in-session with trade-off analysis and WBS | 70% |
| Append-only logging | Runtime-enforced, model cannot rewrite | Prompt-instructed, same file pattern | 75% |
| Push notifications | SendUserMessage with proactive status | File-based + Windows toast for P0/P1 | 60% |
| Always-on daemon | True background process | RemoteTrigger in Anthropic cloud (1h min interval) | 70% |
| GitHub integration | Native webhook subscriptions | gh CLI polling every 5 min | 65% |
| Session awareness | Tracks session count, idle time | Session counter in startup hook | 50% |
| Output tiers | BriefTool with 3 rendering modes | Not replicable (runtime UI feature) | 0% |

**Overall: ~85% coverage.** See [docs/gaps_list.md](docs/gaps_list.md) for the full gap analysis.

### What Pantheon Can't Do (Yet)

These require native runtime features that Anthropic will ship with Kairos (reportedly May 2026):

1. **SleepTool** -- dedicated yield that avoids API cost entirely (we mitigate with pre-check bash gate)
2. **BriefTool output tiers** -- three rendering modes (brief-only, default, transcript). This is a UI feature.
3. **Sub-second tick injection** -- Kairos ticks are injected into the message queue at runtime speed. Our minimum is 10 min local / 1 hour remote.

When Kairos ships, Pantheon's skill definitions and patterns should integrate naturally since they follow the same architecture.

## File Structure

```
pantheon/
  skills/
    pantheon.md      # Orchestrator — scheduling, monitoring, lifecycle
    argos.md         # Daemon — decide-act-sleep evaluation loop
    morpheus.md      # Memory — 4-phase consolidation process
    athena.md        # Planning — deep strategic analysis
  hooks/
    argos-precheck.sh    # Lightweight pre-check gate (saves ~80% API cost)
    pantheon-notify.sh   # Notification system (file + Windows toast)
  docs/
    gaps_list.md         # Full Kairos vs Pantheon gap analysis
    architecture.md      # Detailed architecture documentation
  install.sh             # Interactive installer
  LICENSE                # Apache 2.0
  README.md              # This file
```

## How It Saves Money

Without the pre-check gate, a 10-minute Argos schedule makes ~144 API calls/day, most of which find nothing to do. The `argos-precheck.sh` gate runs a lightweight bash check (~1 second) before each tick:

- `git status` -- any uncommitted changes?
- `gh pr list` -- any open PRs?
- `.pytest_cache/lastfailed` -- any failing tests?
- `TECH_DEBT.md` -- any open items?
- Memory staleness -- last dream >24h ago?

If nothing changed, the tick is skipped entirely. In practice, this eliminates **~80% of API calls** for idle projects.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated
- `git` and `gh` (GitHub CLI) installed and authenticated
- Bash shell (Git Bash on Windows works)
- Optional: PowerShell (for Windows toast notifications)

## Contributing

Contributions welcome. Please open an issue first for significant changes.

Focus areas:
- Additional notification backends (Slack, Discord, email)
- Better session tracking and trigger gates
- Remote trigger prompt optimization
- Integration with upcoming Kairos features

## License

Apache 2.0 -- see [LICENSE](LICENSE).

## Credits

Created by [Panikos Christofi](https://github.com/Panikos). Inspired by the Kairos, autoDream, and ULTRAPLAN architectures discovered in the Claude Code source leak of March 2026.

Built with Claude Code (Opus 4.6).
