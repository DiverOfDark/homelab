# PRD: Personal Productivity Ops Hub (v2)

## Status
Draft

## Author
Femto

## Date
2026-03-22

## Summary
Build a **Telegram-based Personal Productivity Ops Hub** for Kirill using **one group with multiple topics** as the operational interface for personal productivity, homelab operations, and useful workflow events.

This system is **not** just an alert sink. It should combine:
- infra alerts
- calendar awareness
- task focus
- important email and document triage
- money and media workflow events
- useful digests and nudges

The goal is to reduce context switching and make Telegram the place where the highest-signal personal and technical events arrive in a structured, low-noise way.

---

## Problem
Kirill's operational state is fragmented across many systems:
- calendar
- task list
- email
- Paperless/documents
- finance tracking
- media automation
- homelab infra / GitOps / monitoring

As a result:
- important items are noticed late
- useful workflow events get lost
- too many systems must be checked manually
- notifications are either absent or noisy and poorly routed

The system needs a unified interface that surfaces only high-value signals and organizes them by topic.

---

## Vision
Create a Telegram group that functions as a **personal ops console**:
- one place to understand what matters today
- one place to see important workflow events
- one place to receive meaningful infra alerts
- one place to get nudges and summaries

This should feel closer to a curated command center than to a bot spamming random logs.

---

## Goals

### Primary goals
1. Provide a single operational surface for:
   - calendar
   - tasks
   - email and documents
   - finances
   - media workflow events
   - homelab infra
2. Separate signals into Telegram topics to preserve readability.
3. Support four message classes:
   - alerts
   - events
   - digests
   - nudges
4. Keep the system useful every day, not only during failures.

### Secondary goals
1. Make it easy to add new sources incrementally.
2. Support batching, suppression, and escalation.
3. Enable agent-generated synthesis across multiple sources.

### Non-goals
- Replace Grafana, Prometheus, ArgoCD, Paperless, email UI, or calendar UI.
- Stream all logs to Telegram.
- Notify on every state change from every app.
- Turn Telegram into a generic chat bot for everything.

---

## Product principles

### Signal over noise
Every message should be:
- actionable,
- contextually useful,
- or meaningfully informative.

If it does not change what the user knows or does, it probably should not be sent.

### Topic-first routing
Messages should be routed by domain/purpose, not dumped into one mixed stream.

### Alerts are not events
- **Alerts** = failures, risk, degradation, urgency
- **Events** = useful state changes
- **Digests** = periodic summaries
- **Nudges** = context-aware prompts

### Human cadence
Prefer:
- one good digest over ten tiny notifications
- one nudge at the right time over repeated nags
- domain separation over giant mixed chatter

---

## Primary user
- Kirill

## User context
- technical operator and builder
- uses Telegram as the main communication surface
- has a non-trivial self-hosted stack
- values automation, but only when it improves attention and decision-making

---

## User needs
The user wants to:
1. Understand each day quickly:
   - what is on the calendar
   - what matters most today
   - what requires reaction
2. See meaningful workflow events without opening many apps.
3. Receive infra alerts without living inside dashboards.
4. Get summaries and nudges rather than random spam.
5. Keep everything in one place while still preserving structure.

---

## Information architecture
Use **one Telegram group with topics**.

### Topic 1 — `📅 Today`
Purpose:
- calendar awareness
- daily planning context
- schedule warnings

Message types:
- morning day overview
- upcoming important meeting reminder
- evening tomorrow preview
- overlap/conflict or overloaded-day warnings

Sources:
- calendar provider(s)
- task digest synthesis

---

### Topic 2 — `✅ Focus`
Purpose:
- tasks
- priorities
- daily and weekly focus

Message types:
- daily digest
- top 3 priorities
- next best task suggestion
- stalled task nudges
- weekly planning summary

Sources:
- `TASKS.md`
- manual notes
- future integrations with issue trackers / project systems

---

### Topic 3 — `📬 Inbox`
Purpose:
- email
- documents
- admin triage

Message types:
- important new email
- new Paperless document that matters
- invoice/tax/bank/admin item arrived
- item requiring review or follow-up
- inbox summary digest

Sources:
- email provider(s)
- Paperless
- document processing pipelines

---

### Topic 4 — `💸 Money`
Purpose:
- personal finance events and nudges

Message types:
- income recorded
- large expense
- uncategorized transactions
- threshold/budget nudge
- daily/weekly finance summary

Sources:
- Actual / money-api flows
- manual expense/income tracking

---

### Topic 5 — `🎬 Media`
Purpose:
- useful media automation events

Message types:
- new episode downloaded
- film ready
- request fulfilled
- season completed
- media import complete

Sources:
- Sonarr
- Radarr
- Jellyseerr
- Plex/Emby import completion where available

---

### Topic 6 — `🖥 Infra`
Purpose:
- homelab alerts
- deploy and platform state changes

Message types:
- critical alerts
- warning alerts
- backup failures
- GitOps/deploy failures
- storage/network/auth issues

Sources:
- Prometheus / Alertmanager
- ArgoCD
- backup jobs
- storage stack
- network edge stack

---

### Topic 7 — `🪶 FYI`
Purpose:
- low-priority informational summaries
- routine completions worth seeing but not worth interruption

Message types:
- successful backup summaries
- successful routine jobs
- low-priority system summaries
- optional weekly rollups

---

## Event taxonomy

### Alerts
Definition:
Events that indicate failure, degradation, or risk and require attention.

Examples:
- Ceph degraded
- backup failed
- app unavailable
- cert issue

Routing:
- usually `🖥 Infra`
- only immediate if actionable and meaningful

### Business / workflow events
Definition:
Useful state changes that are not failures.

Examples:
- new episode downloaded
- important email arrived
- new document imported
- income recorded

Routing:
- topic-specific
- immediate or near-immediate depending on importance

### Digests
Definition:
Scheduled summaries that compress multiple inputs.

Examples:
- morning daily overview
- inbox summary
- finance summary
- weekly planning summary

Routing:
- scheduled
- highly structured

### Nudges
Definition:
Context-aware prompts that encourage action without escalating like alerts.

Examples:
- tomorrow starts early
- 4 uncategorized transactions remain
- document arrived but no task exists
- a task has stalled for a week

Routing:
- topic-specific
- selective, not frequent

---

## Functional requirements

### FR1. Topic-aware delivery
Every source must map to a Telegram topic.

### FR2. Message class routing
The system must distinguish between alerts, events, digests, and nudges.

### FR3. Daily planning support
The system must generate daily planning messages combining tasks and calendar context.

### FR4. Email triage support
The system must support email-derived signals such as:
- important unread messages
- admin/finance/travel/work emails requiring attention
- digest-level inbox summaries

### FR5. Document triage support
The system must support Paperless/document-derived signals such as:
- important new document
- review required
- invoice/bank/tax/admin category items

### FR6. Finance event support
The system must support income/spending events and basic budget nudges.

### FR7. Media event support
The system must support useful media automation events without spamming internal downloader chatter.

### FR8. Infra visibility
The system must support infrastructure alerts and key operational events.

### FR9. Noise control
The system must support:
- batching
- deduplication
- suppression
- escalation thresholds
- source filtering

### FR10. Human-readable Telegram formatting
All messages must be concise, skimmable, and Telegram-friendly.

---

## Source systems and signals

## Calendar
Useful signals:
- morning overview
- next important meeting
- tomorrow preview
- overlap or overload warnings

Do not send:
- every edit
- every recurring trivial reminder

---

## Tasks
Useful signals:
- daily focus digest
- top 3 priorities
- stalled tasks
- weekly planning summary

Do not send:
- raw full list repeatedly
- duplicate reminders without new context

---

## Email
Useful signals:
- important unread mail
- admin/finance/travel/work mail worth attention
- mail requiring same-day action
- digest of unresolved important messages

Do not send:
- full inbox firehose
- newsletters unless explicitly wanted
- every single unread email

Notes:
Email should be treated as a triage source, not mirrored blindly.

---

## Documents / Paperless
Useful signals:
- important new document
- invoice/tax/bank/admin item
- needs review
- classification failure on important docs

Do not send:
- every routine OCR success
- every low-value document immediately

---

## Money
Useful signals:
- income recorded
- large expense
- uncategorized transactions
- threshold/budget nudges

Do not send:
- every tiny transaction immediately unless explicitly requested

---

## Media
Useful signals:
- episode downloaded
- movie available
- request fulfilled
- library import completed

Do not send:
- downloader chatter
- every internal step of automation

---

## Infra
Useful signals:
- critical/warning alerts
- backup failures
- deploy failures
- storage/network/auth problems
- key GitOps failures

Do not send:
- raw logs
- every successful reconciliation
- every harmless restart

---

## Message design

### General style
- concise
- structured
- domain-appropriate
- clearly action-oriented where needed

### Digest messages
Should include:
- summary first
- bullets second
- one recommended focus or next step where relevant

### Event messages
Should include:
- what happened
- why it matters
- what to do next (if anything)

### Alert messages
Should include:
- what broke
- likely impact
- urgency
- next recommended action

---

## Cadence model

### Immediate
Use for:
- alerts
- important workflow events
- time-sensitive reminders

### Scheduled
Use for:
- daily planning digests
- inbox summaries
- finance summaries
- weekly reviews

### Nudge-based
Use for:
- unresolved items
- stalled tasks
- tomorrow prep
- review queues

---

## MVP v2 scope

### Included topics
- `📅 Today`
- `✅ Focus`
- `📬 Inbox`
- `💸 Money`
- `🎬 Media`
- `🖥 Infra`

### Explicitly removed from this version
- `📸 Photos`
- `Phos` event stream

Rationale:
The first useful version should focus on the operational domains with the clearest day-to-day leverage.

### Included sources in MVP
- calendar
- task list
- email (triaged, not mirrored)
- Paperless/documents
- Actual/money tracking
- media automation
- Prometheus/Alertmanager + key infra systems

---

## Rollout plan

## Phase 1 — Core daily ops
Build:
- `📅 Today`
- `✅ Focus`
- `📬 Inbox`
- `🖥 Infra`

Deliver:
- morning digest
- calendar previews
- important email/doc triage
- infra alerts routed correctly

Why first:
This provides immediate daily utility and creates the backbone of the system.

---

## Phase 2 — Personal workflow events
Add:
- `💸 Money`
- `🎬 Media`

Deliver:
- income / large expense / uncategorized nudges
- new episode/movie/request-completed events

Why second:
These are high-value and pleasant signals, but not foundational to the daily planning layer.

---

## Phase 3 — Intelligence and synthesis
Add:
- cross-source nudges
- weekly review
- suggestion layer

Examples:
- important email arrived and no task exists yet
- tomorrow meeting is early and day is overloaded
- documents requiring review remain unresolved
- free slot today matches stalled task

---

## Delivery model: cron vs event-driven

### Cron-driven
Use for:
- morning digest
- evening tomorrow preview
- inbox summary
- finance summary
- weekly planning/review

### Event-driven
Use for:
- infra alerts
- important email arrival
- important document arrival
- media download completion
- large income/expense events

### Hybrid
Use for:
- nudges that depend on both state and time
- unresolved queue summaries
- “this matters now” synthesis

---

## Success criteria
The system is successful if:
1. Kirill checks the group daily because it helps him steer the day.
2. Important events are seen sooner than before.
3. Noise stays low enough that topics remain readable.
4. Email/doc/task/calendar context is easier to process from Telegram.
5. Infra alerts and workflow events coexist without becoming chaos.

---

## Risks

### Risk 1 — notification overload
Mitigation:
- aggressive filtering
- topic separation
- summary-first delivery

### Risk 2 — weak email triage quality
Mitigation:
- start with narrow high-value categories
- refine rules iteratively
- keep raw inbox out of Telegram

### Risk 3 — overengineering too early
Mitigation:
- start with MVP topics only
- add sources gradually

### Risk 4 — mixed semantics between alerts and events
Mitigation:
- define per-source routing rules
- use domain topics and message classes explicitly

---

## Open questions
1. Which email categories matter enough for immediate delivery vs digest only?
2. Should `📬 Inbox` combine email + Paperless, or should documents split out later?
3. How much finance granularity is useful before it becomes noisy?
4. Should media events be immediate or batched by time window?
5. Should future messaging include weather/travel context in `📅 Today`?
6. Should weekly review live in `✅ Focus` or `🪶 FYI`?

---

## Recommendation
Treat this as a **personal operations system**, not an alert collector.

Start with:
- `📅 Today`
- `✅ Focus`
- `📬 Inbox`
- `🖥 Infra`

Then add:
- `💸 Money`
- `🎬 Media`

Keep `Photos/Phos` out of v2 for now.
Add email explicitly as a first-class source.
Use cron for digests and event hooks for important state changes.
