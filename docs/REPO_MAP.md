# Repository Map

## Root

- `README.md`
  - public project overview
- `CANONICAL_BASELINE.md`
  - single entry document and precedence anchor for future maintenance
- `VERSION`
  - GUI package version used by build scripts
- `.github/workflows`
  - CI and release workflows
- `assets`
  - app logo, bundled resources, demo assets
- `docs`
  - long-term engineering notes and handoff documents

## GUI Source

- `mac_app/gui/DevelopmentBoardToolchainGUI.swift`
  - main SwiftUI application source
- `mac_app/gui/build_gui_app.sh`
  - local GUI build and packaging script

## Build Validation Sources

- `mac_app/swift-cli`
  - compatibility validation sources required by the GUI build flow

## Packaging

- `scripts/package_gui_release.sh`
  - builds the GUI release output for distribution
- `dist/gui_app`
  - generated local packaging output

## Docs Added For Continuation

- `docs/GUI_PROJECT_OVERVIEW.md`
- `CANONICAL_BASELINE.md`
- `docs/PROJECT_CORE_POINTS.md`
- `docs/TOOL_INTERACTION_PROTOCOL.md`
- `docs/REPO_MAP.md`
- `docs/GUI_BASELINE_2026-04-14.md`
- `docs/NEXT_MODEL_PROMPT.md`
- `docs/STACK_BASELINE_2026-04-14.md`
- `docs/DBT_AGENTD_BASELINE.md`
- `docs/OPENCODE_DBT_AGENT_PROTOCOL.md`
- `docs/OFFLINE_PACKAGE_BASELINE.md`
- `docs/MULTI_CLIENT_DEVICE_COORDINATION.md`
- `docs/RP2350_INITIAL_FIRMWARE_BASELINE.md`
- `docs/boards/TaishanPi_GUI.md`
- `docs/boards/ColorEasyPICO2_GUI.md`
