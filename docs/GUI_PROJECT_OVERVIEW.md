# GUI Project Overview

This document is the canonical entry for the macOS GUI project.

Project root:

- `development-board-toolchain-gui/`

Repository intent:

- all GUI source, build scripts, packaging scripts, assets, and long-term GUI documentation must stay inside this repository
- future GUI work should not depend on editing files outside this repository
- external runtime components such as `dbt-agentd` and `dbtctl` are integration targets, not source locations for this GUI project

Read order for future model work:

1. `README.md`
2. `CANONICAL_BASELINE.md`
3. `docs/PROJECT_CORE_POINTS.md`
4. `docs/TOOL_INTERACTION_PROTOCOL.md`
5. `docs/REPO_MAP.md`
6. board-specific GUI notes under `docs/boards/`

Path rule:

- if an older archival note still mentions a file path outside this repository, treat it as historical context only
- do not use external file paths as the active source for GUI changes

Primary code locations:

- `mac_app/gui/DevelopmentBoardToolchainGUI.swift`
- `mac_app/gui/build_gui_app.sh`
- `mac_app/swift-cli/`
- `scripts/package_gui_release.sh`

Board-specific GUI notes:

- `docs/boards/TaishanPi_GUI.md`
- `docs/boards/ColorEasyPICO2_GUI.md`

Working rule:

- if a GUI task can be solved entirely inside this repository, do not reach outside this repository
- if a tool protocol changes, update `docs/TOOL_INTERACTION_PROTOCOL.md` first, then adapt GUI code
- do not create release tags unless explicitly requested
