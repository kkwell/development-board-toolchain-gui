# Next Model Prompt

Use the prompt below when handing this repository to another model for continued GUI development.

```text
You are continuing work on the macOS GUI project in this repository.

Read these files first:
- CANONICAL_BASELINE.md
- README.md

Important rules:
- This repository contains the GUI project only.
- Treat `CANONICAL_BASELINE.md` as the single entry document. If another doc conflicts with it, follow `CANONICAL_BASELINE.md`.
- Do not bundle or redesign private runtime payloads here.
- The GUI should behave as a client of local dbt-agentd.
- Unified board status must come from dbtctl status --json through dbt-agentd.
- Do not reintroduce legacy local service fallback paths.
- TaishanPi logic and ColorEasyPICO2 logic must remain isolated so one board’s UI logic does not break the other.
- Do not create a release or bump version unless explicitly requested.
- When changing tool interaction behavior, update docs/TOOL_INTERACTION_PROTOCOL.md in the same change.

Implementation target:
- Make the requested GUI change with the smallest coherent patch.
- Validate by building the GUI locally.
- If the change affects tool interaction or board state mapping, explain the exact protocol assumption that changed.
```
