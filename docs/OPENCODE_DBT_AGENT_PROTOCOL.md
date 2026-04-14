# OpenCode <-> DBT Agent Protocol

This document records the current OpenCode plugin contract for version `1.0.4`.

It is not the same as the GUI protocol. The GUI and OpenCode use the same `dbt-agentd` control plane, but they expose different user flows and different tool surfaces.

## Primary Source Files

- plugin source:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/plugins/development-board-toolchain.js](/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/plugins/development-board-toolchain.js)
- plugin documentation:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/README.md](/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/README.md)
- release repo:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo)
- installed plugin copy:
  - `~/.config/opencode/plugins/development-board-toolchain/index.js`

## Architectural Rule

OpenCode must call `dbt-agentd`, not raw `dbtctl`, as the normal path.

Preferred flow:

- OpenCode model
- OpenCode plugin tools
- local `dbt-agentd`
- local `dbtctl`
- board hardware

## Default Tooling Strategy

The plugin exposes a validated high-level tool set only.

Current core tool groups:

### Status / scope

- `dbt_get_status`
- `dbt_current_board_status`
- `dbt_prepare_request`
- `dbt_list_capability_summaries`

### Capability / board context

- `dbt_get_board_config`
- `dbt_get_capability_context`

### TaishanPi runtime

- `dbt_probe_chip_control`
- `dbt_get_cpu_frequency`
- `dbt_get_ddr_frequency`
- `dbt_get_cpu_temperature`
- `dbt_probe_wifi_bluetooth`
- `dbt_connect_wifi`
- `dbt_scan_wifi_networks`
- `dbt_scan_bluetooth_devices`
- `dbt_build_run_program`
- `dbt_update_logo`
- `dbt_ensure_usbnet`

### Plugin / update

- `dbt_check_plugin_update`
- `dbt_update_plugin`

### ColorEasyPICO2 runtime / environment

- `dbt_rp2350_detect`
- `dbt_rp2350_enter_bootsel`
- `dbt_rp2350_flash`
- `dbt_rp2350_verify`
- `dbt_rp2350_run`
- `dbt_rp2350_tail_logs`
- `dbt_rp2350_save_flash`
- `dbt_check_board_environment`
- `dbt_install_board_environment`

## Required Request Flow

For board-scoped design or execution requests:

1. call `dbt_get_status`
2. call `dbt_prepare_request`
3. call `dbt_list_capability_summaries`
4. select the best capability
5. call `dbt_get_capability_context`
6. continue with execution or code generation

Do not skip directly to a guessed capability name.

## Scope Rules

- if a board is connected, prefer that board
- if no board is connected and the user explicitly names a board, allow knowledge/capability lookup for that board
- if no board is connected and the user does not name a board, stop and ask for the board model
- if execution requires live hardware and the board is not connected, return a clear execution-blocked error

## Why This Protocol Is Separate From GUI

OpenCode has model-facing concerns that the GUI does not have:

- tool descriptions
- tool alias normalization
- scope resolution prompts
- capability summary selection
- plugin auto-update and manifest handling

These do not belong in the GUI protocol file.

## Update / Install Path

OpenCode plugin update now uses release-manifest assets, not the old raw repository-clone path.

Primary release repo files:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/index.js](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/index.js)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/release-manifest.json](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/release-manifest.json)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/install-opencode-plugin.sh](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo/install-opencode-plugin.sh)

## Anti-Patterns

Do not reintroduce:

- `dbt_server_*` remote generation as the default path
- broad tool surfaces that expose both high-level and raw low-level tools to the model
- direct plugin calls to raw `dbtctl` for normal user flows
- full all-board knowledge dumps into the model context

## When To Update This Document

Update this file when changing:

- OpenCode tool names
- tool semantics
- scope flow
- plugin update/install behavior
- the board-environment install/check path exposed to OpenCode
