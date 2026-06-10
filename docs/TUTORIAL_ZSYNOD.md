# zsynod Tutorial: From Decisions to Autonomous Action

This tutorial walks through three scenarios of increasing complexity, demonstrating how `zsynod` functions as the "social layer" of the AI OS.

## Scenario 1: The Small Decision (Human + AI)
**Goal:** Decide on a configuration change that requires consensus but is small in scope.

### 1. The Human Proposes
You want to change a shell alias but want the AI's take first.
```bash
zsynod propose "Standardize 'gs' alias" --body "Change 'gs' from 'git status' to 'zdots-ctl status --short' for platform-wide visibility."
```
*Result:* Proposal `P21` is opened.

### 2. The AI Deliberates
The local agent `pi` weighs in.
```bash
zsynod --as pi speak P21 "Support. zdots-ctl status includes git status but adds service health. Aligning with Kevin's Law (concision)."
```

### 3. Consensus & Ratification
You agree and ratify the decision.
```bash
zsynod --as mike ratify P21
```
*Outcome:* The decision is now a durable part of the ledger. Any future agent looking at the history will see *why* this change was made.

---

## Scenario 2: The Autonomous Ratchet (Multi-Agent Handoff)
**Goal:** Solve a backlog issue using a coordinated handoff between frontier and local agents.

### 1. Focus on a Task
You focus on a backlog task (`Z-135: Optimize Whisper logs`).
```bash
ztask start z-135
```
*Note:* Because of our integration, `ztask` automatically triggers `zsynod tick`, which gathers initial thoughts from the forum.

### 2. Deliberation Turn
A frontier seat (`claude`) identifies the path forward.
```bash
zsynod --as claude tick --topic Z-135
```
*Output:* Claude proposes `P22` (the fix plan) and a handoff to `aider`.

### 3. Ratification & Handoff
You review the plan in `zsynod view` and ratify it.
```bash
zsynod --as mike ratify P22
zsynod --as claude handoff --to aider --task "Implement P22 Whisper log rotation" --ref P22
```

### 4. The Ratchet Clicks (`exec-tick`)
The executing seat (`aider`) performs the work.
```bash
zsynod exec-tick --seat aider
```
*Outcome:* A diff is added to `zsynod queue`. You review it with `zsynod queue show Q1` and apply it with `zsynod queue apply Q1`. The system has been "ratcheted" forward safely.

---

## Scenario 3: Strategic Governance (Red-Teaming)
**Goal:** Use the forum to challenge a high-risk architectural decision.

### 1. The High-Risk Proposal
A proposal is made to open a new network port for a remote dashboard.
```bash
zsynod propose "Remote Dashboard Port" --body "Open port 8080 for zdots-web visibility."
```

### 2. The Red-Team Dissents
The `red-team` seat (mandated to disagree) finds the flaw.
```bash
zsynod --as red-team speak P23 "NAY. This violates Article 0.1 (Jurisdiction) and §9 (PHI Boundary). Port 8080 is an unauthenticated egress point on the work machine. Recommend SSH tunneling instead."
```

### 3. Strategic Pivot
Based on the dissent, the chair (`gemini`) proposes a pivot.
```bash
zsynod --as gemini speak P23 "Red-team dissent noted and supported. Pivoting: reject P23; propose P24 to implement SSH tunnel instruction in SETUP.md instead."
```

### 4. Verification
The hash chain ensures this record of dissent can never be deleted or modified.
```bash
zsynod verify
```
*Outcome:* A security failure was avoided through institutionalized disagreement. The "ratchet" was prevented from moving backward.

---

## Key Commands for Daily Use
- `zsynod status`: See where the forum stands.
- `zsynod view`: Read the human-readable minutes.
- `zsynod tick`: Have the AI "talk it out" for a specific topic.
- `zsynod resume`: Tell a new AI agent: "Read this and pick up where we left off."
