# DBT Stack Baseline 2026-04-14

Current validated stack version:

- `1.0.5`

This document is the top-level index for the current `dbt-agentd`-centric architecture.

## Current Control Plane Rule

- `dbt-agentd` is the local control plane.
- `dbtctl` is the local execution backend.
- `OpenCode` is the current install, validation, and primary user-entry environment.
- `GUI` is a separate client and should follow the same local-agent contract.
- `Hermes` is no longer the main validation path for this version.
- Current validated hardware baseline includes simultaneous `TaishanPi` + `ColorEasyPICO2` attachment through the same local control plane.

## Read Order For Future Development

If the next AI session needs to continue from this version, read in this order:

1. [DBT_AGENTD_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/DBT_AGENTD_BASELINE.md)
2. [OPENCODE_DBT_AGENT_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OPENCODE_DBT_AGENT_PROTOCOL.md)
3. [TOOL_INTERACTION_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/TOOL_INTERACTION_PROTOCOL.md)
4. [OFFLINE_PACKAGE_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OFFLINE_PACKAGE_BASELINE.md)
5. [MULTI_CLIENT_DEVICE_COORDINATION.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/MULTI_CLIENT_DEVICE_COORDINATION.md)
6. [RP2350_INITIAL_FIRMWARE_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/RP2350_INITIAL_FIRMWARE_BASELINE.md)

## Component Boundaries

### `dbt-agentd`

Responsibilities:

- board detection and status aggregation
- board-scoped capability summaries and full context lookup
- environment check and install
- plugin install and discovery
- job submission for long-running actions
- local knowledge and offline package discovery
- device identity and lease coordination baseline
- RP2350 initialization firmware path and asset baseline

Must not do:

- act as the main LLM runtime
- expose raw `dbtctl` internals directly to the model

### `OpenCode` plugin

Responsibilities:

- expose validated high-level tools to the model
- resolve scope through `dbt-agentd`
- install and update runtime assets
- call only the local `dbt-agentd` control plane
- attach client/session ownership metadata to control-plane POST requests

Must not do:

- reintroduce legacy `dbt_server_*` remote generation
- call raw `dbtctl` directly as the normal path
- expose all boards or all knowledge at once

### Offline packages

Responsibilities:

- provide per-board offline installable bundles
- stage plugins and board environments without network
- support manual upload to private servers

## Source Of Truth Split

Keep these documents separated:

- [TOOL_INTERACTION_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/TOOL_INTERACTION_PROTOCOL.md)
  - GUI <-> `dbt-agentd` / `dbtctl` contract only
- [OPENCODE_DBT_AGENT_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OPENCODE_DBT_AGENT_PROTOCOL.md)
  - OpenCode plugin <-> `dbt-agentd` contract only
- [DBT_AGENTD_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/DBT_AGENTD_BASELINE.md)
  - control plane responsibilities, endpoints, and source layout
- [OFFLINE_PACKAGE_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OFFLINE_PACKAGE_BASELINE.md)
  - release packaging, board environments, and offline bundles

Do not merge all of these into one protocol file. The GUI and OpenCode clients have different responsibilities and different failure modes.

## Key Source Locations

- `dbt-agentd` Swift service:
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Sources/DBTAgentd/main.swift`
- `dbtctl` runtime integration:
  - installed under `~/Library/development-board-toolchain/runtime/dbtctl`
  - accessed only through `dbt-agentd` and documented in `docs/TOOL_INTERACTION_PROTOCOL.md`
- OpenCode plugin source:
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/plugins/development-board-toolchain.js`
- OpenCode release repo source:
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/opencode_plugin_release_repo`
- Release packaging scripts:
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_publish_tree.sh`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_environment_bundles.sh`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_offline_packages.sh`

## Installed Runtime Paths

- shared root:
  - `~/Library/development-board-toolchain`
- installed `dbtctl`:
  - `~/Library/development-board-toolchain/runtime/dbtctl`
- installed `dbt-agentd`:
  - `~/Library/development-board-toolchain/agent/bin/dbt-agentd`
- installed user plugins:
  - `~/Library/development-board-toolchain/plugins/user`
- installed board environments:
  - `~/Library/development-board-toolchain/families/rp2350/shared/board-environments`
- staged offline board environment archives:
  - `~/Library/development-board-toolchain/families/rp2350/shared/board-environments`

## Maintenance Rule

When changing behavior:

1. Update the relevant protocol document first.
2. Update the implementation.
3. Validate with `OpenCode`.
4. Only then package or release.
