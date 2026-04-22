# development-board-toolchain-gui

Open-source macOS GUI project for `DBT-Agent`.

This repository is the canonical macOS GUI project for `DBT-Agent`.

It contains the menu bar application source, the `dbt-agentd` HTTP protocol client models used by the GUI, GUI assets, packaging scripts, and long-term GUI maintenance notes.

## Demo

Click the preview below to open the original WebM recording.

[![DBT-Agent GUI demo](assets/demo/gui_demo.gif)](assets/demo/gui_demo.webm)

## Scope

- GUI app bundle name: `DBT-Agent.app`
- GUI in-app title: `Development Board Toolchain`
- Release archive: `DBT-Agent-<version>.zip`

This repository builds and releases the GUI application package.

For GUI maintenance, treat this repository as self-contained. External runtime components such as local `dbt-agentd`, `dbtctl`, and installed board plugins are integration targets, not source locations for this GUI project.

## Licensing

This repository is released under the MIT License.

Use, modification, redistribution, and commercial use are allowed, provided the original copyright notice and license text are retained.

## Project Layout

- `mac_app/gui`
  - `DevelopmentBoardToolchainGUI.swift`
  - `build_gui_app.sh`
- `assets`
  - app icon and bundled GUI assets
- `scripts`
  - release packaging helpers
- `.github/workflows`
  - CI build and tagged release workflows
- `docs`
  - archived engineering notes, protocol notes, and handoff material

## Engineering Notes

- [GUI Project Overview](docs/GUI_PROJECT_OVERVIEW.md)
- [Canonical Baseline](CANONICAL_BASELINE.md)
- [Project Core Points](docs/PROJECT_CORE_POINTS.md)
- [Tool Interaction Protocol](docs/TOOL_INTERACTION_PROTOCOL.md)
- [Repository Map](docs/REPO_MAP.md)
- [GUI Baseline 2026-04-14](docs/GUI_BASELINE_2026-04-14.md)
- [Next Model Prompt](docs/NEXT_MODEL_PROMPT.md)
- [TaishanPi GUI Notes](docs/boards/TaishanPi_GUI.md)
- [ColorEasyPICO2 GUI Notes](docs/boards/ColorEasyPICO2_GUI.md)

## Local Build

```bash
./mac_app/gui/build_gui_app.sh
```

Build output:

- `mac_app/gui/build/DBT-Agent.app`
- `mac_app/gui/build/DBT-Agent-<version>.zip`

## Local Release Packaging

```bash
./scripts/package_gui_release.sh
```

Release output:

- `dist/gui_app/DBT-Agent-<version>.zip`
- `dist/gui_app/manifest.json`
- `dist/gui_app/toolkit-manifest.json`

The GUI release package contains the application bundle only.

It does **not** bundle:

- `dbtctl`
- `dbt-agentd`
- shared runtime payloads
- hardware operation toolchains

Those are installed and updated separately under `~/Library/development-board-toolchain`.

For a working GUI install, both of these local components must exist:

- `~/Library/development-board-toolchain/runtime/dbtctl`
- `~/Library/development-board-toolchain/agent/bin/dbt-agentctl`
- `~/Library/development-board-toolchain/agent/bin/dbt-agentd`

Optional environment variables:

- `APP_VERSION_OVERRIDE`
- `APP_BUILD`
- `DOWNLOAD_BASE_URL`

## GitHub Actions

- `build.yml`
  - Builds the GUI on push and pull request
- `release.yml`
  - Builds and publishes release assets on tag push `v*`

## Notes

- The GUI is designed to work with the shared local install root under `~/Library/development-board-toolchain`.
- The app itself does not bundle the full runtime or `dbt-agentd`; those are installed and updated separately by the product installer/runtime.
- Board-family assets should resolve the canonical family layout first, for example `families/rk356x/boards/TaishanPi/variants/1M-RK3566/images/` and `families/rp2350/boards/<BoardID>/assets/`.
- The full product installer is expected to provision both `runtime/` and `agent/`. If `agent/` is missing, the GUI now reports the missing local install path instead of only showing a generic unavailable state.
- The GUI only owns the local `dbt-agentd` service process it starts itself. It may clean up that GUI-owned process tree after a GUI-side job timeout, but it must not terminate `--mcp-serve` or unrelated agent processes.
