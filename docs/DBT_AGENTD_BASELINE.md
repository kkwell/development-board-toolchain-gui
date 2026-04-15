# DBT Agentd Baseline

This document records the current `dbt-agentd` baseline for version `1.0.5`.

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

Current installed baseline now includes:

- `device_id`
- `device_uid`
- `active_device_id`
- `devices[]`
- `transport_locator`
- `display_label`
- simultaneous multi-device aggregation for:
  - `TaishanPi`
  - `ColorEasyPICO2`
  - `RaspberryPiPico2W`

Current validated behavior:

- `GET /v1/status/summary` and `GET /v1/status/live` now expose both connected boards in `devices[]`
- `active_device_id` remains a compatibility pointer for clients that still assume one active device
- the current selection rule prefers the authoritative runtime device, and in the validated two-board setup that currently resolves to `TaishanPi`
- `device_id` is now scoped to a stable board-family identifier instead of the raw transport locator
- `transport_locator` remains the current connection endpoint, such as `198.19.77.1` or `/dev/cu.usbmodem112301`
- current stable identity rule:
  - `TaishanPi`: `taishanpi::1m-rk3566::<stable_uid>`
  - `ColorEasyPICO2`: `coloreasypico2::coloreasypico2::<hardware_uid>`
  - `RaspberryPiPico2W`: `raspberrypipico2w::raspberrypipico2w::<hardware_uid>`
- current networking compatibility rule:
  - legacy TaishanPi USB ECM remains accepted as `198.19.77.2 <-> 198.19.77.1`
  - new multi-board TaishanPi scheme is reserved as one `/30` per board slot
  - target shape is `198.19.<slot>.1 <-> 198.19.<slot>.2`
  - current host-side slot registry path:
    - `~/Library/Application Support/development-board-toolchain/state/taishanpi-usbnet-slots.json`
  - current online migration gate:
    - disabled by default
    - enabled only when `DBT_USBNET_ENABLE_SLOT_MIGRATION=1`

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
- `RaspberryPiPico2W`
  - shares the RP2350 family environment baseline with `ColorEasyPICO2`

Environment install is now treated as a host-scoped maintenance action, not a device-scoped action.

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

Mutating job creation now carries normalized request ownership metadata:

- `client_id`
- `session_id`
- `client_type`
- `request_id`

and the internal job/lease records use that metadata for conflict ownership.

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

## Current Coordination Baseline

The current installed baseline already includes:

- device-scoped lease plumbing for mutating board operations
- host-maintenance lease plumbing for environment install
- `resolved_device_id` in scope resolution responses when the current connected board is the chosen target
- multi-device status aggregation across Linux-board and RP2350 probes

This is not yet the final multi-device UI/UX model, but it is now a working control-plane baseline rather than just a reserved response shape.

## Knowledge Sources

Authoring source remains in:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/vault](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/vault)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/registry](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/registry)

Compiled or published data consumed by the runtime is derived from:

- `vault/published`
- `registry/published`

## RP2350 Initialization Firmware Baseline

The maintained RP2350 initialization firmware source-of-truth is documented in:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/RP2350_INITIAL_FIRMWARE_BASELINE.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/RP2350_INITIAL_FIRMWARE_BASELINE.md)

Current fixed source roots:

- `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/ColorEasyPICO2`
- `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W`

Current fixed runtime asset roots:

- `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/toolkit-runtime/assets/ColorEasyPICO2/initial.uf2`
- `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/toolkit-runtime/assets/RaspberryPiPico2W/initial.uf2`

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

Validated runtime/environment behaviors include:

- single-USB runtime detection
- enter `BOOTSEL`
- return to runtime
- tail logs
- environment check for `full_build`

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
- future multi-client and multi-device changes must follow:
  - [MULTI_CLIENT_DEVICE_COORDINATION.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/MULTI_CLIENT_DEVICE_COORDINATION.md)
