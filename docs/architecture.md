# Pantheon Architecture

## Design Philosophy

Pantheon is built on three principles:

1. **Act or sleep, never narrate.** An autonomous agent that says "nothing to report" is wasting tokens. If there's no work, silence is the correct output.
2. **Cost-awareness by design.** Every tick that reaches the LLM costs money. The architecture minimises unnecessary API calls through pre-check gates and skip logic.
3. **Two-tier resilience.** Local execution for speed and context; remote execution for persistence. Neither tier alone is sufficient.

## Component Architecture

### Pantheon (Orchestrator)

The control plane. Manages lifecycle, scheduling, and coordination of all agents.

**Responsibilities:**
- Schedule/cancel local cron jobs (Tier 1)
- Create/manage remote triggers (Tier 2)
- Report status across all agents
- Provide unified entry points (`pantheon dream`, `pantheon plan`)

**Does NOT:**
- Evaluate project state (that's Argos)
- Touch memory files (that's Morpheus)
- Generate plans (that's Athena)

### Argos (Daemon)

The evaluation engine. Runs on every tick and decides what to do.

**Decision model:** Priority ladder evaluated top-to-bottom. First category with actionable work wins.

```
P0 BROKEN STATE        Fix immediately. Tests failing, type errors, build broken.
P1 ACTIVE SIGNALS      Respond to events. New PRs, issues, recent commits.
P2 BACKLOG             Resolve tracked work. Tech debt, unreleased changelog items.
P3 DOCUMENTATION       Fix drift. Docs that don't match code reality.
P4 QUALITY             Harden. Test gaps, coverage, CI completeness.
P5 PROACTIVE           Maintain. Memory consolidation, TODO cleanup.
P6 ALL CLEAR           Sleep. Log and yield.
```

**One unit of work per tick.** Argos never batches. This keeps each tick fast, reviewable, and independently revertible.

**Logging:** Append-only daily files at `logs/YYYY/MM/YYYY-MM-DD.md`. Each entry records what, why, files changed, and result. The log is the audit trail -- Argos never rewrites history.

### Morpheus (Memory Consolidation)

Maintains clean, non-contradictory project memory across sessions.

**Four-phase process:**

```
Phase 1: ORIENT
  Read MEMORY.md index and all memory files.
  Categorise by type (user, feedback, project, reference).
  Assess overall health.

Phase 2: GATHER RECENT SIGNAL
  Collect observations from git log, Argos logs, recent sessions.
  Classify each as: confirmed fact, tentative insight, or contradiction.

Phase 3: CONSOLIDATE
  Merge confirmed facts into existing memories.
  Upgrade tentative insights with supporting evidence.
  Resolve contradictions by checking current code state.
  Delete memories derivable from code/config.

Phase 4: PRUNE AND INDEX
  Enforce 200-line limit on MEMORY.md.
  Enforce 25KB limit per memory file.
  Rebuild index with semantic grouping.
  Add dream timestamp metadata.
```

**Trigger gates (automatic mode):**
1. Time gate: 24+ hours since last dream
2. Activity gate: 3+ sessions since last consolidation (tracked by session counter)
3. Lock gate: no concurrent dream running

**Read-only for code.** Morpheus writes only to memory files and MEMORY.md. It never modifies source code.

### Athena (Deep Planning)

Exhaustive planning for complex, ambiguous problems.

**Five-phase process:**

```
Phase 1: PROBLEM DECOMPOSITION
  Read codebase, docs, git history.
  Identify the real problem (not just the symptom).
  Define success criteria. Map known/unknown/unknown-unknowns.

Phase 2: OPTION GENERATION (divergent)
  Generate 3+ distinct approaches.
  Include at least one unconventional option.
  For each: architecture, pros, cons, effort, risk, reversibility.

Phase 3: TRADE-OFF ANALYSIS (convergent)
  Decision matrix with weighted criteria.
  Score each option, compute weighted totals.
  Make a recommendation with explicit reasoning.

Phase 4: IMPLEMENTATION BLUEPRINT
  Work breakdown structure (epics -> stories -> tasks).
  Execution sequence with gates and rollback plans.
  Risk register with probability, impact, mitigation.
  Decision log.

Phase 5: DELIVERY
  Save plan as PLAN-[topic]-[date].md.
  Present executive summary and first 3 tasks.
  Ask for approval before executing.
```

**Always on-demand.** Athena is never scheduled automatically. Deep planning should be intentional.

### Hermes (Parallel Coordinator)

Decomposes complex tasks into independent subtasks and dispatches them to parallel worker agents.

**Six-phase process:**

```
Phase 1: DECOMPOSE
  Break task into independent subtasks, organized into waves.
  Wave 1 = no dependencies (run in parallel).
  Wave 2+ = depends on prior wave results.

Phase 2: DISPATCH
  Launch all wave workers simultaneously using Agent tool:
    run_in_background: true
    isolation: "worktree" (each worker gets isolated git copy)

Phase 3: PERSIST MANIFEST
  Save task state to project-scoped hermes_manifest.json.
  Enables cross-session resume if session closes mid-task.

Phase 4: COLLECT
  Background agents notify on completion.
  Update manifest. If wave complete, dispatch next wave.

Phase 5: RECONCILE
  Review all results. Detect conflicts (same file modified by 2 workers).
  Merge worktree branches. Run full test suite.

Phase 6: CLEANUP
  Remove worktree branches. Update manifest. Log to Argos daily log.
```

**Cross-session resilience:** The manifest persists at `~/.claude/projects/<PROJECT_ID>/pantheon/hermes_manifest.json`. If a session closes mid-task, `/hermes continue` reads the manifest, checks which workers completed (worktree branches survive session death), and re-dispatches pending subtasks.

**Integration:** Athena produces plans with WBS → Hermes can execute them as parallel subtasks. Argos can invoke Hermes for large P2 backlog tasks. Morpheus consolidates learnings after Hermes completes.

## Two-Tier Execution Model

### Tier 1: Local Execution

```
CronCreate (durable: true)
  |
  +-- Every N minutes (while REPL is idle)
       |
       +-- argos-precheck.sh
            |
            +-- changed? --> /argos --> act/sleep --> log --> notify
            +-- no change? --> skip (free)
```

**Characteristics:**
- Fast: 10-minute intervals
- Context-rich: has conversation history, local files, notification system
- Ephemeral: dies when terminal closes (schedule persists for restart)
- Cost-mitigated: pre-check gate skips ~80% of ticks

### Tier 2: Remote Execution

```
RemoteTrigger (Anthropic cloud)
  |
  +-- Every 1-2 hours (always, even terminal closed)
       |
       +-- Fresh git checkout of repo
       +-- Self-contained Argos prompt (no prior context)
       +-- Full evaluation cycle
       +-- Commits and pushes to repo
```

**Characteristics:**
- Persistent: runs in Anthropic's cloud regardless of terminal state
- Independent: fresh session each time, no conversation history
- Git-only: can only access the repository, not local files
- Higher latency: 1-hour minimum interval

### Tier Interaction

Both tiers write to the same `logs/` directory in the repository. If Tier 2 commits a fix, Tier 1 will see it on its next `git status` check and skip redundant work.

## Pre-Check Gate

The `argos-precheck.sh` script is the key cost-saving mechanism.

**Checks performed (~1 second total):**
1. `git status --porcelain` -- uncommitted changes?
2. `git log --since="15 minutes ago"` -- recent commits?
3. `gh pr list --limit 1` -- open PRs?
4. `.pytest_cache/lastfailed` -- failing tests?
5. `TECH_DEBT.md` grep for "open" -- tracked work?
6. MEMORY.md timestamp -- memory stale >24h?

**Output:** `{"changed": true, "signals": ["uncommitted_changes", "open_prs"]}` or `{"changed": false}`

If `changed: false`, the tick is skipped entirely -- no LLM invocation, no API cost.

## Notification System

The `pantheon-notify.sh` script provides multi-channel notifications:

**Channels:**
1. `~/.claude/notifications/current.json` -- latest notification (overwritten). Duskit or other watchers read this file.
2. `~/.claude/notifications/history.jsonl` -- append-only audit log of all notifications.
3. Windows toast notification via PowerShell -- P0/P1 severity only.

**Notification format:**
```json
{
  "ts": "2026-04-03T14:30:00Z",
  "source": "ARGOS",
  "severity": "P0",
  "message": "Failing tests detected in src/api",
  "local_time": "14:30"
}
```

## Session Tracking & Auto-Start

### State File Scoping

Pantheon state is split into two categories to support parallel sessions:

**Global state** (`~/.claude/`):
- `pantheon_disabled` — opt-out flag (affects ALL sessions/projects)
- `pantheon_deploy_active` — remote deploy marker (one remote trigger is shared)
- `pantheon_hook.sh`, `pantheon_stop_hook.sh` — the hook scripts themselves

**Project-scoped state** (`~/.claude/projects/<PROJECT_ID>/pantheon/`):
- `autostart_fired` — 30-min cooldown per project
- `schedule_meta.json` — interval preference per project
- `session_count` — counter for Morpheus gates per project

The project ID is derived from `$PWD` using: `pwd | sed 's|^/c/|C--|' | sed 's|^/[A-Za-z]/|/|' | sed 's|^/||' | sed 's|/|-|g'` — matching Claude Code's own `projects/` directory naming.

### Auto-Start Flow

A `SessionStart` hook manages session lifecycle:

1. Derives project path from `$PWD`
2. Increments project-scoped session counter
3. Checks `~/.claude/pantheon_disabled` (global) — if present, skips
4. Checks project-scoped `autostart_fired` — if touched within 30 min, skips
5. Checks `~/.claude/scheduled_tasks.json` for an active Argos cron
6. If schedule exists: quiet confirmation
7. If no schedule: `[PANTHEON-AUTOSTART]` directive with project-scoped interval preference

**Auto-start is a directive, not a suggestion.** Claude starts Pantheon and announces it — no user permission required. Users opt out via the `pantheon_disabled` file.

**Self-renewal:** Argos checks its own schedule age on every tick (P5.5 priority). If the schedule was created >6 days ago, it auto-renews by deleting and recreating the cron job. No manual `/pantheon renew` needed.

Morpheus reads the session counter for its activity gate and resets it after consolidation.

## Comparison to Kairos Internal Architecture

| Kairos Component | Pantheon Equivalent | Implementation Difference |
|---|---|---|
| `<tick>` message injection | CronCreate + RemoteTrigger | Kairos injects at runtime level; we use cron scheduling |
| SleepTool | argos-precheck.sh | Kairos yields inside the LLM turn; we skip before the turn |
| BriefTool / SendUserMessage | pantheon-notify.sh | Kairos has 3 UI rendering tiers; we write to files + toast |
| autoDream forked sub-agent | /morpheus skill | Same 4-phase logic; different trigger mechanism |
| ULTRAPLAN remote container | /athena skill | Kairos has dedicated 30-min cloud compute; we run in-session |
| Append-only daily logs | Same pattern, prompt-enforced | Kairos enforces at runtime; we instruct in the prompt |
| 15-second blocking budget | Mentioned in prompt | Kairos auto-backgrounds; we can't enforce at runtime |
| Coordinator Mode (parallel workers) | /hermes skill | Kairos has native mailbox; we use Agent tool with run_in_background + worktree |
| GitHub webhook subscriptions | gh CLI polling via cron | Kairos is push-based; we poll |
