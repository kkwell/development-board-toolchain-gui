# Canonical Baseline

This is the single entry document for this repository.

If any linked document conflicts with this file, this file wins.

Use this file first for:

- GUI changes
- OpenCode plugin changes
- `dbt-agentd` / `dbtctl` integration changes
- offline package changes
- RP2350-family packaging and runtime behavior

## Current Product Topology

This repository is the canonical GUI-facing project root for `DBT-Agent`.

For GUI work, do not treat files outside this repository as the source of truth.

The delivered product is split into:

- GUI app
- shared runtime
- local `dbt-agentd`
- board plugins
- board development environments
- offline install bundles

The GUI does not bundle the full runtime or `dbt-agentd`.

## Documentation Precedence

Use this order:

1. `CANONICAL_BASELINE.md`
2. area-specific baseline or protocol document linked from this file
3. historical notes

Do not start by reading a long unordered doc list.

## Current Board Families

### TaishanPi

- Linux board family
- Docker-heavy compile environment remains separate
- offline package remains separate from RP2350

### RP2350 Family

Current supported board models:

- `ColorEasyPICO2`
- `RaspberryPiPico2W`

Rules:

- they share one compiler and Pico SDK base
- they differ by board metadata, board constraints, initialization firmware, and capability guidance
- they must be distinguished by stable `hardware_uid`, not by transient serial paths
- generated code must follow the capability build contract returned by `dbt-agentd`

## RP2350 Packaging Rules

Current split:

- shared `RP2350RuntimeCore`
- shared `RP2350SDKCore`
- board overlay archive under the compatibility profile name `full_build`

Key facts:

- `RP2350RuntimeCore` contains the shared runtime-only content:
  - `picotool`
  - validation UF2 images
- `RP2350SDKCore` contains the heavy shared content:
  - toolchain
  - `pico-sdk`
  - `picotool`
  - shared Pico SDK dependencies
- `ColorEasyPICO2/minimal_runtime` is no longer published
- `RP2350BuildOverlay/full_build` is no longer a duplicated full SDK package
- `RP2350BuildOverlay/full_build` is now the shared RP2350 build overlay archive
- `dbtctl` now resolves RP2350 builds from shared `sdk_core` first
- `dbtctl` now resolves RP2350 runtime operations from shared `runtime_core` when only runtime assets are installed

Verified build path:

- generated RP2350 projects resolve `PICO_SDK_PATH` to:
  - `~/Library/Application Support/development-board-toolchain/board-environments/RP2350SDKCore/sdk_core/RP2350/pico-sdk`

## RP2350 Offline Bundle Rules

The offline packaging unit for RP2350 is one shared family bundle, not separate per-board bundles.

Reason:

- `ColorEasyPICO2` and `RaspberryPiPico2W` share the same development and compile environment
- the difference is in board identity, capability constraints, and board-specific examples
- those differences belong in plugins, knowledge, initialization firmware, and runtime identity
- they should not force duplicate offline SDK bundles

Current RP2350 offline bundle contents:

- both RP2350 board plugins
  - `ColorEasyPICO2`
  - `RaspberryPiPico2W`
- shared `RP2350RuntimeCore`
- shared `RP2350SDKCore`
- shared RP2350 build overlay archive:
  - `RP2350BuildOverlay/full_build`

## Build Order Rules

For release packaging, the order is mandatory:

1. `product_release/build_board_environment_bundles.sh`
2. `product_release/build_board_offline_packages.sh`

The offline bundler must fail if required prebuilt archives are missing.

## GUI Rules

GUI is a client of local `dbt-agentd`.

Rules:

- unified board status must come from local tool/runtime status through `dbt-agentd`
- do not reintroduce legacy local fallback paths
- multi-device UI must be driven by stable device identity
- board-specific UI behavior must not be hardcoded into generic shared flows

Primary GUI detail docs:

- [GUI Baseline](docs/GUI_BASELINE_2026-04-14.md)
- [Tool Interaction Protocol](docs/TOOL_INTERACTION_PROTOCOL.md)
- [TaishanPi GUI Notes](docs/boards/TaishanPi_GUI.md)
- [ColorEasyPICO2 GUI Notes](docs/boards/ColorEasyPICO2_GUI.md)

## OpenCode / Control Plane Rules

Rules:

- `dbt-agentd` is the authority for capability context and implementation contracts
- the model must not invent Pico SDK headers, include paths, support headers, or link libraries from scratch
- RP2350 generated code must follow `implementation_contract.build_contract`
- board type selection belongs to runtime identity and board profile binding, not to transient serial paths
- OpenCode local default model baseline is `google/gemini-2.5-flash-lite`
- do not use `google/gemini-2.5-flash` as the default local model for DBT multi-tool flows in this environment; it produced incomplete turns and `finish=other` / empty-stop behavior during real validation
- `dbt_current_board_status` must stay compact; do not return the full raw `runtime_status` blob to the model
- `dbt_current_board_status` is the canonical connected-device and live-status entry:
  - it already includes the connected device list and active device
  - do not force a second `list_connected_devices` call when status already answers the question
- for capability-list and board-how-to questions, prefer direct capability lookup:
  - `dbt_get_board_capabilities`
  - or `dbt_prepare_request` plus capability summaries/context
  - do not require a prior status call when live execution state is irrelevant
- only require live status precheck before:
  - flashing
  - runtime execution
  - deployment
  - hardware tests
  - connection-state diagnosis
- `dbt_get_board_config` must return a minimal model-facing contract:
  - compact board metadata
  - for RP2350 boards, the actual installed `runtime_root`, `sdk_core_root`, `build_overlay_root`, `pico_sdk_path`, `picotool_path`, `pioasm_path`, and `arm_none_eabi_gcc`
- `dbt_get_capability_context` must return only the minimal implementation contract needed for generation:
  - required headers
  - include directories
  - link libraries
  - support headers
  - selected capability profile
- `experimental.chat.messages.transform` must not inject large demo transcripts or few-shot examples into every request
- `dbt-agentd /v1/agent/resolve-scope` must not return `should_stop = false` together with an empty `recommended_tools` list; when scope resolution succeeds, it must always provide at least one concrete next tool

Primary control-plane docs:

- [DBT Agentd Baseline](docs/DBT_AGENTD_BASELINE.md)
- [OpenCode DBT Agent Protocol](docs/OPENCODE_DBT_AGENT_PROTOCOL.md)
- [Codex Plugin Install](docs/CODEX_PLUGIN_INSTALL.md)

## Codex Plugin Rules

`DBT-Agent` is the Codex-facing name for `Development Board Toolchain`.

Codex must use the same shared support-root runtime and local agent as GUI and OpenCode.

Canonical install shape:

- shared runtime root:
  - `~/Library/Application Support/development-board-toolchain/runtime`
- shared agent root:
  - `~/Library/Application Support/development-board-toolchain/agent`
- Codex plugin install target:
  - `~/.codex/.tmp/plugins/plugins/dbt-agent`
  - or `~/plugins/dbt-agent` depending on the active Codex local marketplace root
- Codex marketplace file:
  - `~/.codex/.tmp/plugins/.agents/plugins/marketplace.json`
  - or `~/.agents/plugins/marketplace.json`

Runtime asset layout for Codex is now:

- `runtime/editor_plugins/codex/plugin/dbt-agent`
- `runtime/editor_plugins/codex/marketplace.json`
- `runtime/editor_plugins/codex/scripts/dbt_agent_mcp.py`

Obsolete path:

- `runtime/codex_plugin`
- do not reintroduce it

Rules:

- the installed Codex plugin id is `dbt-agent`, and the UI display name is `DBT-Agent`
- the installed Codex plugin is a thin wrapper only; its `.mcp.json` must point to the shared runtime script under `runtime/editor_plugins/codex/scripts/dbt_agent_mcp.py`
- GUI, OpenCode, and Codex must all operate through the same support-root runtime and local `dbt-agentd`
- Codex plugin tools must stay compact and model-facing
- do not proxy long raw `dbt-agentd` payloads into Codex
- `dbt_current_board_status` and `dbt_rp2350_detect` must be fast and compact
- `dbt_get_board_config` for RP2350 must be synthesized as minimal path/config contract
- `dbt_get_capability_context` must return only the implementation contract needed for code generation
- when a backend job path is unstable or blocks, the Codex plugin must prefer a compact local/status-derived implementation over exposing a hanging tool
- current desktop baseline: do not proxy `dbtctl release check-update` or `dbtctl release install-codex-plugin` directly from the Codex MCP layer; in this environment they can hang, so Codex maintenance tools must use the release manifest plus runtime/agent install scripts directly
- remove legacy Codex plugin ids `development-board-toolchain` and `rk356x-mac-toolkit` when installing the canonical Codex plugin

Validated Codex plugin tools:

- `dbt_current_board_status`
- `dbt_list_connected_devices`
- `dbt_prepare_request`
- `dbt_list_capability_summaries`
- `dbt_list_installed_board_plugins`
- `dbt_list_available_board_plugins`
- `dbt_search_board_plugins`
- `dbt_get_board_config`
- `dbt_get_capability_context`
- `dbt_check_board_environment`
- `dbt_install_board_environment`
- `dbt_check_plugin_update`
- `dbt_update_plugin`
- `dbt_rp2350_detect`
- `dbt_rp2350_tail_logs`
- `dbt_probe_chip_control`
- `dbt_probe_wifi_bluetooth`

Parity rules:

- Codex plugin must cover the current OpenCode default DBT tool surface
- current parity result is full coverage for active OpenCode default DBT tools
- Codex plugin also keeps three local catalog helpers that OpenCode does not expose by default:
  - `dbt_list_installed_board_plugins`
  - `dbt_list_available_board_plugins`
  - `dbt_search_board_plugins`

Current Codex plugin board scope:

- `TaishanPi / 1M-RK3566`
- `ColorEasyPICO2`
- `RaspberryPiPico2W`

## RP2350 Initialization Firmware Rules

For GUI work, only rely on the initialization-firmware contracts and release-facing assets documented inside this repository.

Release initialization images:

- identify the board correctly
- keep DBT runtime identity available
- do not need to include full user feature logic
- for `Pico 2 W`, may initialize `CYW43` and blink the wireless LED so power-on is visible

Primary RP2350 docs:

- [RP2350 Initial Firmware Baseline](docs/RP2350_INITIAL_FIRMWARE_BASELINE.md)
- [RP2350 SDK Package Plan](docs/RP2350_SDK_PACKAGE_PLAN.md)

## Offline Packaging Detail

Primary offline package baseline:

- [Offline Package Baseline](docs/OFFLINE_PACKAGE_BASELINE.md)

Use it for exact archive names, sizes, and install paths.

## Repository Orientation

If code navigation is needed:

- [Repository Map](docs/REPO_MAP.md)

## Handoff Rule

For future model handoff, point the next model to this file first.
