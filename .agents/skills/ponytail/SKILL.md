---
name: ponytail
description: Audits code, designs, and architectural proposals against premature technical debt. Cuts speculative abstractions, simplifies over-engineered solutions, and enforces explicit '# ponytail: <rationale>' markers on pragmatic shortcuts. Use during code review, feature planning, refactoring, or when asking for a simpler, leaner design.
---

# /ponytail — Reducing Premature Technical Debt

The **Ponytail Skill** is a disciplined razor against speculative engineering.

Premature abstraction is the most expensive technical debt because you pay the maintenance, testing, and cognitive taxes on code that serves zero real callers.

---

## 1. When to Use This Skill

- **During Feature Planning**: When a proposal introduces new configuration matrices, plugin systems, microservices, or complex inheritance hierarchies.
- **During Code Review**: When a diff has more boilerplate, wrapper code, or interfaces than actual business logic.
- **When Feeling Drag**: When modifying a simple behavior requires touching 4+ files across multiple abstraction layers.
- **When User Asks**: When the user says "ponytail this", "simplify this", "is this over-engineered?", or "cut premature debt".

---

## 2. The Complexity Razor: 5 Interrogations

Run these questions against any proposed design or diff:

1. **The Caller Count**: How many distinct callers exist for this abstraction *today*?
   - If 1: Inline it or keep it concrete.
   - If 0 (speculative): Delete it immediately (Rung 1: Omission).
2. **The Config Trap**: Are we introducing a YAML file or database table for 2–3 static values?
   - Replace with inline constants or code defaults.
3. **The Layer Check**: Does this class/module simply pass parameters through to another layer without transforming data or enforcing a domain invariant?
   - Collapse the wrapper. Let the caller touch the seam directly.
4. **The Concurrency / Scale Trap**: Are we introducing async queues, mutexes, or background workers for a single-operator local machine?
   - Default to standard library synchronous operations unless latency measurements demand otherwise.
5. **The Searchable Seam**: Did we mark the intentional trade-off?
   - Add `# ponytail: <why simple is enough, and what triggers an upgrade>`.

---

## 3. The Ponytail Ladder

Always stop at the lowest rung that satisfies the requirement:

| Rung | Action | Description |
|------|--------|-------------|
| **1. Omission** | Delete / Don't write | Zero lines of code carry zero bugs and zero maintenance cost. |
| **2. Inlining** | Constants over Config | Hardcode sensible defaults directly where used. |
| **3. Stdlib Simplicity** | Procedural / Built-ins | Standard loops and stdlib over heavy external dependencies. |
| **4. Annotated Seam** | `# ponytail: <rationale>` | Explicitly document the pragmatic boundary and upgrade condition. |

---

## 4. How to Annotate a Seam

When taking a deliberate, pragmatic shortcut, never hide it. Format the comment as:

```ruby
# ponytail: <what was simplified> — <why it is sufficient for single-operator local platform>;
# upgrade trigger: <condition that justifies building full abstraction>.
```

Example:
```ruby
# ponytail: thresholds are inline constants, not a YAML config — one operator on localhost;
# upgrade trigger: extract to config if multi-tenant thresholds are ever required.
MAX_DRIFT = 5
```

---

## 5. Audit Workflow for Agents

When requested to review or write code with the Ponytail skill:
1. **List all new files and abstractions** introduced in the plan.
2. **Apply the Complexity Razor** to each.
3. **Recommend cuts** (e.g. "We don't need `RegistryFactory`—a simple Hash map in `bus.rb` eliminates 40 lines").
4. **Ensure remaining trade-offs are tagged** with `# ponytail:`.
