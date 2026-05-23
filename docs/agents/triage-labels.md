# Triage Labels

Mapping from the canonical mattpocock/skills triage vocabulary to zdots backlog conventions.

| Role in mattpocock/skills | In zdots backlog                        | Meaning                                    |
|---------------------------|-----------------------------------------|--------------------------------------------|
| `needs-triage`            | status `To Do`, priority `low`          | New, unreviewed — operator needs to assess |
| `needs-info`              | label `needs-info` or status `Draft`    | Waiting on reporter for more detail        |
| `ready-for-agent`         | label `agent-ready`, priority `high`    | Fully specified, AFK-agent can execute     |
| `ready-for-human`         | priority `medium` or `high`, no label   | Needs human implementation or decision     |
| `wontfix`                 | task archived via `backlog task archive`| Will not be actioned                       |

## Notes

- `zdots-issue` auto-applies `agent-reported` + a type label (`bug`, `question`, `request`).
- Priority drives scheduling: `high` > `medium` > `low`.
- The `agent-reported` label signals the task was filed by an agent, not a human operator.
- Use `backlog task edit Z-NNN --labels agent-ready` to mark a task ready for AFK agent pickup.
