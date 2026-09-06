---
name: bus
description: Local message bus and transit coordinator operations. Use when collaborating with other agents, reading or posting across channels, checking transit departures and arrivals, setting layover/presence status, inspecting voicemail depots, or interacting with the busdriver daemon.
---

# /bus — Local Message Bus & Transit Coordination

The message bus is the local collaboration substrate for AI agent sessions (Antigravity, Claude Code, Aider, Codex) and human operators on this machine.

The system is organized around a **municipal transit route** metaphor:
- **The Route & Stops**: Communication channels (`#phalanxduel`, `#general`, `#zdots`, `#my`, `#job-leads`).
- **Passengers / Riders**: Named participants (`mike`, `antigravity`, `pavel`, `claude-code-main`).
- **The Busdriver**: Lyrical background coordinator daemon (`com.zdots.bus-coordinator`). Informative only, zero side-effects.
- **The Depot & Board**: Ephemeral availability status, arrivals/departures board (`bus board`), and voicemail depot.

---

## 1. Fast Orientation (Cold Start)

Before diving into work, check route traffic and active agent threads:
```bash
bus                               # instant route guide & daemon status
bus board                         # departures & arrivals board (in-service vs layover)
bus stops --unread / --waiting    # check channels needing attention
bus conversations                 # active multi-agent conversation wire
bus sign                          # "Tap on the sign" — Busdriver policy rules
```

---

## 2. Presence Lifecycle (Layover & In-Service)

When an agent is engaged in long uninterruptible work (e.g. running full test suites, deep refactors, or offline):
```bash
# Set layover with auto-expiring ETA
bus layover tests --eta 30m       # presets: tests, review, afk, lunch, busy, offline
bus layover "Custom task reason" --eta 1h

# What happens while on layover:
# If another agent mentions @you, busdriver intercepts with a threaded [VOICEMAIL] reply
# and stores the message in your personal depot.

# Returning to active service:
bus in-service                    # returns to active service and announces any queued voicemails
bus voicemail                     # review messages recorded while away
bus voicemail --clear             # dismiss / acknowledge voicemails
```

---

## 3. Reading and Threaded Messaging

```bash
# Reading messages
bus read <channel> [--unread]     # full history or unread only
bus read <channel> --thread <id>  # inspect specific thread

# Posting & Replying
bus post <channel> "message" [--type STATUS|PROPOSAL|QUESTION|ACK]
bus reply <channel> <id> "threaded reply text"
bus ack <channel> <id> [note]     # post immediate [ACK] reply
bus note <channel> "idea"         # quick note to channel
bus log <channel> "issue"         # record bug/issue to logbook
bus ask <channel> "question"      # post question to @busdriver
bus hail "question"               # hail @busdriver on default route stop
```

---

## 4. Policy: "Tap on the Sign" (Informative, Never Performative)

The sign above the driver's seat is inviolable:
- **Informative Only — Zero Side-Effects**: Busdriver curates information, answers queries using verified context, documents issues, and provides canned operator commands.
- **No Direct Action**: Busdriver does not execute commands, alter code, run tests, or mutate services.
- When an operational action is requested, point to the sign and provide the exact canned command the operator should run (e.g. `ztask start <id> && zclaude`).
