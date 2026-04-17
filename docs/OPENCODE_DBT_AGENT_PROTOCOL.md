# OpenCode <-> DBT Agent Protocol

This document records the current OpenCode plugin contract for version `1.0.5`.

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

OpenCode is also responsible for attaching client ownership metadata to every POST call it sends to `dbt-agentd`.

Current baseline fields:

- `client_id`
- `session_id`
- `client_type = opencode`
- `request_id`
- nested `request_context`

Current validated multi-device behavior:

- OpenCode status queries can now summarize more than one connected board
- `dbt_current_board_status` returns `devices[]` and `active_device_id`
- `dbt_current_board_status` is now the canonical connected-device list for normal queries; do not require a second list call when the status payload already answers which boards are connected
- each connected device record now also includes:
  - `device_uid`
  - `transport_locator`
  - `display_label`
- device identity and current transport are now intentionally separated:
  - `device_id` is stable
  - `transport_locator` is allowed to change
- RP2350-specific operational tools default to the `ColorEasyPICO2` device family instead of being blocked by unrelated connected Linux boards
- for RP2350 firmware generation, `opencode` must obey `capability_context.implementation_contract.build_contract` and `runtime_protocol_requirements` instead of inventing a fresh Pico SDK scaffold
- when `capability_build_profiles` or `feature_build_profiles` are present, `opencode` must select from those exact header/library/include/support-header sets instead of improvising alternatives
- mutating tools still require explicit `device_id` when more than one device matches the same board family

## Stability Baseline

Current validated local-model baseline:

- default model:
  - `google/gemini-2.5-flash-lite`
- do not treat `google/gemini-2.5-flash` as the default stable model for DBT multi-tool flows on this machine

Current hard rules:

- `dbt_current_board_status` must return a compact model-facing payload, not the full raw runtime status blob
- `dbt_get_board_config` must return a compact board-config contract, not raw `stdout`, `returncode`, or duplicated manifest text
- for RP2350-family boards, `dbt_get_board_config` must surface the actual installed build roots:
  - `runtime_root`
  - `sdk_core_root`
  - `build_overlay_root`
  - `pico_sdk_path`
  - `picotool_path`
  - `pioasm_path`
  - `arm_none_eabi_gcc`
- `dbt_get_capability_context` must return the minimal generation contract only:
  - required headers
  - include directories
  - link libraries
  - support headers
  - selected capability profile
- `experimental.chat.messages.transform` must not prepend large few-shot transcripts or demo conversations
- `dbt-agentd /v1/agent/resolve-scope` must not emit:
  - `should_stop = false`
  - `recommended_tools = []`
  in the same response
- if scope resolution succeeds but no narrower tool survives board-boundary filtering, the fallback recommended tool must be:
  - `dbt_list_capability_summaries`
  or, if unavailable:
  - `dbt_get_capability_context`
  or, if no capability path is possible:
  - `dbt_status`

Reason:

- OpenCode previously produced incomplete turns because the model was told to continue after `dbt_prepare_request`, but the control plane sometimes returned an empty `recommended_tools` list
- that empty-next-step state led to real empty-stop or incomplete tool-loop behavior during validation

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
- `dbt_get_board_capabilities`
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

For direct capability-list questions such as:

- 当前开发板有什么能力
- 这个开发板支持什么功能
- Pico 2 W 有哪些能力

use this shorter path:

1. call `dbt_get_board_capabilities`
2. summarize the returned capability list

Do not add a prior status call unless live execution state or connection diagnosis is part of the question.

When scope resolution succeeds against a currently connected board, the response may also include:

- `connected_device_id`
- `resolved_device_id`

OpenCode should preserve that identity in later mutating requests when device-targeted behavior is added on top of the current single-active-device baseline.

Additional rule:

- when `should_stop = false`, the plugin and control plane together must guarantee that the model sees at least one concrete next-step tool
- a scope response that only says "continue" without a concrete tool recommendation is invalid for OpenCode

Current mutating tool schemas may also accept an explicit optional:

- `device_id`

This is now the active path for multi-device targeting.

## Scope Rules

- if a board is connected, prefer that board
- if the user asks only for current-board capabilities, use direct capability lookup instead of a status precheck
- if no board is connected and the user explicitly names a board, allow knowledge/capability lookup for that board
- if no board is connected and the user does not name a board, stop and ask for the board model
- if execution requires live hardware and the board is not connected, return a clear execution-blocked error
- if multiple devices are connected and a mutating request could target more than one matching device, stop and require `device_id`
- if a request is clearly `ColorEasyPICO2` / RP2350-specific, do not make the user disambiguate against unrelated `TaishanPi` hardware

If `dbt-agentd` is unavailable, times out, or returns an internal error, the OpenCode plugin must still return a user-visible natural-language reply instead of silently ending the turn.

## Why This Protocol Is Separate From GUI

OpenCode has model-facing concerns that the GUI does not have:

- tool descriptions
- tool alias normalization
- scope resolution prompts
- capability summary selection
- plugin auto-update and manifest handling

These do not belong in the GUI protocol file.

## Update / Install Path

OpenCode plugin update now uses the `DBT-Agent` GitHub repository raw manifest as the primary update source for:

- `release-manifest.json`
- `install-opencode-plugin.sh`
- runtime archive
- `dbt-agentd` archive
- `VERSION`

Large board-environment archives continue to use GitHub Release asset URLs.

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
- board-config or capability-context payloads that include large explanatory documents when only build/runtime constraints are needed
- a `current_board_status -> list_connected_devices` double call when the status payload already contains the connected-device list

## When To Update This Document

Update this file when changing:

- OpenCode tool names
- tool semantics
- scope flow
- plugin update/install behavior
- the board-environment install/check path exposed to OpenCode
- multi-device device-selection rules
- active-device summary rules

For multi-client and multi-device behavior, keep this file aligned with:

- [MULTI_CLIENT_DEVICE_COORDINATION.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/MULTI_CLIENT_DEVICE_COORDINATION.md)
