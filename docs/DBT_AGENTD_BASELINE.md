# DBT Agentd Baseline

This document records the current `dbt-agentd` baseline for version `1.0.4`.

## Role

`dbt-agentd` is the local control plane.

It sits between user clients and execution tools:

- client -> `dbt-agentd`
- `dbt-agentd` -> `dbtctl`
- `dbtctl` -> local runtime / board hardware

`dbt-agentd` is not the primary model runtime in this version. The model lives in the client environment, and `dbt-agentd` serves board knowledge, scope resolution, environment control, plugin management, and runtime jobs.

## Primary Source Files

- service implementation:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Sources/DBTAgentd/main.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Sources/DBTAgentd/main.swift)
- service package:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Package.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Package.swift)
- local service API notes:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/service/LOCAL_API.md](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/service/LOCAL_API.md)
- local config template:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/service/dbt-agentd.local.template.json](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/service/dbt-agentd.local.template.json)
- board tool boundary manifest:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/manifests/board-tool-boundaries.json](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/manifests/board-tool-boundaries.json)

## Execution Backends

`dbt-agentd` delegates to `dbtctl` runtime code.

Main runtime sources:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/main.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/main.swift)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/BoardCapabilityRuntime.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/BoardCapabilityRuntime.swift)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/RP2350Runtime.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/mac_app/swift-cli/Sources/DBTCtlSwift/RP2350Runtime.swift)

## Current Responsibilities

### Unified status

`dbt-agentd` is the board-status aggregator for:

- TaishanPi
- ColorEasyPICO2

It must return one unified status envelope and avoid board-family-specific public status commands for clients.

### Scope resolution

`dbt-agentd` decides:

- target board
- target variant
- candidate capability set
- whether the request must stop because the board is not connected and the user did not specify a board

### Capability lookup

`dbt-agentd` exposes:

- capability summaries
- full capability context

The current rule is:

- do not expose all boards and all full contexts at once
- first resolve board scope
- then list summaries for that board
- then load only the selected capability context

### Environment management

`dbt-agentd` now supports:

- environment check
- environment install

Current validated board-family environment support:

- `ColorEasyPICO2`
  - `minimal_runtime`
  - `full_build`

### Plugin management

`dbt-agentd` owns:

- list installed plugins
- list available plugins
- search plugins
- install plugins

Current runtime rule:

- plugins are user-installable
- plugins are removable
- `TaishanPi` is no longer treated as a permanent builtin runtime plugin

## Current External API Groups

### Health

- `GET /healthz`

### Status

- `GET /v1/status/summary`
- `GET /v1/status/live`

### Scope / capability

- `POST /v1/agent/resolve-scope`
- `GET /v1/context/capability`
- `GET /v1/context/capabilities`

### Plugins

- `GET /v1/plugins/installed`
- `GET /v1/plugins/available`
- `GET /v1/plugins/search`
- `POST /v1/plugins/install`

### Jobs / runtime actions

- `POST /v1/jobs/flash`
- `POST /v1/jobs/rp2350`
- `POST /v1/jobs/runtime-action`
- `GET /v1/jobs/<job_id>`

### Environment

- `GET /v1/environment/check`
- `POST /v1/environment/install`

### Knowledge / maintenance

- `POST /v1/knowledge/review-cycle`
- `POST /v1/knowledge/publish-review`
- `POST /v1/knowledge/build-release-delta`

Legacy `/v1/hermes/*` compatibility aliases may still exist internally, but they are not the preferred path.

## Installed Paths

- control plane binary:
  - `~/Library/Application Support/development-board-toolchain/agent/bin/dbt-agentd`
- config:
  - `~/Library/Application Support/development-board-toolchain/agent/config`
- agent state:
  - `~/Library/Application Support/development-board-toolchain/agent/state`
- logs:
  - `~/Library/Application Support/development-board-toolchain/agent/logs`
- published knowledge copied into installed agent tree:
  - `~/Library/Application Support/development-board-toolchain/agent/vault`
  - `~/Library/Application Support/development-board-toolchain/agent/registry`

## Knowledge Sources

Authoring source remains in:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/vault](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/vault)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/registry](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/registry)

Compiled or published data consumed by the runtime is derived from:

- `vault/published`
- `registry/published`

## Current Board Scope

### TaishanPi

Validated capabilities include:

- `rgb_led`
- `chip_control`
- `wifi_bluetooth`
- `camera_display`
- `microsd_storage`
- `rtc`
- `pin_header_40pin`
- `gpio`
- `uart`
- `i2c`
- `spi`

### ColorEasyPICO2

Current validated focus is runtime/environment integration:

- single USB state
- BOOTSEL transition
- flash
- verify
- save flash
- runtime log tail
- environment install/check

## Rules For Future Changes

- do not move model orchestration back into `dbt-agentd`
- do not expose raw `dbtctl` tools directly to user-facing clients
- do not reintroduce legacy remote-generation paths as the default control path
- keep board-family-specific internals behind one local control plane contract
