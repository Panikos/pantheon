# Pantheon vs Kairos — Gap Analysis

## Architecture Comparison

| Capability | Kairos (Claude internal) | Pantheon (ours) | Gap Severity |
|---|---|---|---|
| **Tick injection** | Runtime injects `<tick>` into message queue when idle — zero config, always on | CronCreate polls on interval + auto-start hook on session resume | MAJOR → MITIGATED |
| **SleepTool** | Dedicated tool the model calls to yield explicitly, saving API cost | Pre-check bash gate (`argos-precheck.sh`) skips empty ticks before API call | MAJOR → MITIGATED |
| **15s blocking budget** | Runtime auto-backgrounds commands >15s, model stays responsive | Mentioned in Argos prompt but no enforcement — just a prompt instruction | MEDIUM |
| **Append-only logging** | Enforced by runtime — model cannot delete/rewrite logs | Instructed "append only" but nothing prevents the model from rewriting | MEDIUM |
| **SendUserMessage / BriefTool** | Dedicated tool with `status: 'proactive'` vs `'normal'`, three rendering tiers, push notifications | No separate output channel — everything goes to stdout | MAJOR |
| **Durable daemon** | Runs as a true background process, survives terminal close, systemd-style lifecycle | Two-tier: local CronCreate + remote RemoteTrigger (cloud, 1h min) | CRITICAL → MITIGATED |
| **GitHub webhooks** | Native webhook subscriptions — real-time event-driven, not polling | `gh` CLI polling every 5 min via cron | MEDIUM |
| **autoDream** | Forked sub-agent with read-only bash, runs automatically during idle, three-gate trigger system | `/morpheus` functionally equivalent in logic (4-phase, gates, 200-line limit) but must be triggered by Argos or manually | SMALL |
| **ULTRAPLAN** | Remote container running Opus with 30 min dedicated think time, browser UI for approval, `__TELEPORT_LOCAL__` sentinel | `/athena` runs in-session with normal context limits, no remote offload, no dedicated browser UI | MAJOR |
| **Feature flags** | 44 compile-time flags gating capabilities | None — everything is always on | MINOR |
| **Session awareness** | Tracks session count, idle time, last activity automatically | Project-scoped session counter + 30-min cooldown hook | MEDIUM → MITIGATED |
| **Cost management** | Prompt cache expires after 5 min idle — SleepTool balances wake-up cost vs cache expiry | Pre-check gate skips ~80% of ticks | MAJOR → MITIGATED |
| **Coordinator Mode** | One Claude orchestrates parallel workers via mailbox system | No equivalent — `/review-all` chains sequentially | MAJOR |
| **BUDDY companion** | 18 species, 5 stats, rarity tiers, cosmetic system | Duskit exists as minimal companion (no stats/species) | MINOR |
| **Self-Healing Memory** | MEMORY.md as pointer index, topic files on-demand, strict write discipline | Morpheus implements same pattern (index + topic files + 200-line limit) | MATCHED |

## Critical Gaps (ranked by impact)

### GAP-1: Not a real daemon [CRITICAL → MITIGATED]
**Problem:** Pantheon only works while Claude Code is open. Close the terminal, nothing runs.
**Kairos:** Designed as a persistent background service.
**Workaround:** Two-tier architecture using RemoteTrigger API. Tier 2 (`pantheon deploy`) creates a remote daemon in Anthropic's cloud that runs on a cron schedule (min 1 hour) even when the terminal is closed. Combined with Tier 1 local cron (every 10 min while REPL open), this provides near-continuous coverage.
**Limitations:** Remote tier has 1-hour minimum interval (vs Kairos's real-time ticks), git-only access (no local files), and starts fresh each run (no conversation context).
**Status:** MITIGATED — `pantheon deploy` creates cloud-hosted remote daemon

### GAP-2: No SleepTool — wasteful ticks [MAJOR]
**Problem:** Every `/argos` cron tick costs a full API call even when there's nothing to do. On 10-minute interval = ~144 API calls/day, most no-ops.
**Kairos:** Dedicated SleepTool yields cheaply.
**Workaround:** Pre-check script that runs `git status` and `gh pr list` before invoking Claude. Only fires full Argos prompt if something changed.
**Status:** CAN MITIGATE — build pre-check gate

### GAP-3: No push notifications [MAJOR]
**Problem:** No way to alert user on phone/desktop when Argos finds critical issues.
**Kairos:** SendUserMessage with `status: 'proactive'`, push notifications.
**Workaround:** Write to external notification file + have Duskit announce. Could also add Slack/Discord webhook.
**Status:** CAN MITIGATE — build notification file + Duskit integration

### GAP-4: No remote compute for Athena [MAJOR]
**Problem:** Athena runs in local session with normal context limits. Complex planning may hit constraints.
**Kairos:** ULTRAPLAN offloads to cloud container with 30 min Opus think time.
**Workaround:** Use `/schedule` to dispatch to remote agent trigger.
**Status:** CAN MITIGATE — wire remote trigger

### GAP-5: No separate output channel [MAJOR]
**Problem:** Everything Argos does shows up in same conversation. No brief-only mode.
**Kairos:** BriefTool with three rendering tiers (brief-only, default, transcript via ctrl+o).
**Workaround:** Write detailed output to log files, keep conversation output minimal.
**Status:** PARTIALLY MITIGATED — already logging to daily files

### GAP-6: No cost awareness [MAJOR]
**Problem:** No understanding of prompt cache expiry or API call cost.
**Kairos:** Balances wake-up cost vs 5-min cache expiry.
**Workaround:** Pre-check gate (same as GAP-2) reduces unnecessary API calls.
**Status:** CAN MITIGATE — same fix as GAP-2

### GAP-7: Session awareness is coarse [MEDIUM]
**Problem:** Only checks once per 24h via timestamp file.
**Kairos:** Tracks session count, idle time, last activity continuously.
**Workaround:** Enhance hook to track session count in a file.
**Status:** CAN IMPROVE

## What We Got Right

- Decision hierarchy (P0-P6) matches Kairos evaluate-act-sleep pattern
- Morpheus 4-phase consolidation closely mirrors autoDream logic
- Append-only daily file logging pattern (`logs/YYYY/MM/`)
- Durable scheduling via CronCreate survives restarts
- Startup hook checks for active schedule on session start
- Pantheon orchestrator centralizes lifecycle management

## Coverage Estimate

~85% of Kairos vision replicated after mitigations. Remaining gaps (SleepTool cost optimization, BriefTool output tiers, sub-second tick injection) require native runtime features that will ship with Kairos (reportedly May 2026).

## Mitigation Plan

| Gap | Fix | Effort | Impact |
|-----|-----|--------|--------|
| GAP-2 | Pre-check gate script | Small | High — saves ~80% of API calls | **DONE** — `argos-precheck.sh` |
| GAP-3 | Notification file + Duskit | Small | High — user awareness | **DONE** — `pantheon-notify.sh` + Windows toast |
| GAP-7 | Session counter in hook | Small | Medium — better trigger gates | **DONE** — counter in `pantheon_session_count` |
| GAP-4 | Remote trigger for Athena | Medium | Medium — deeper planning | OPEN |
| GAP-1 | Two-tier: RemoteTrigger for cloud daemon | Medium | Critical — always-on coverage | **DONE** — `pantheon deploy` |
| GAP-5 | Already partially mitigated | N/A | N/A | N/A |
