# Multi-Client / Multi-Device Coordination

This document records the required engineering rules for `dbt-agentd` when it is used by multiple clients and multiple connected boards.

Current status:

- the current validated version now exposes a real multi-device `devices[]` list
- `active_device_id` remains the compatibility pointer for legacy single-device clients
- device-scoped mutation guards are live for the validated OpenCode path
- this document still defines the next-step model for richer device selection UX

## Why This Is Required

`dbt-agentd` is a local control plane, not a single-client helper.

That means it must coordinate:

- multiple `OpenCode` sessions
- GUI and `OpenCode` at the same time
- multiple connected boards
- multiple job types competing for the same hardware or host-side resources

Without an explicit coordination model, the following problems are guaranteed:

- two clients flashing the same device at once
- one client forcing BOOTSEL while another is reading logs
- one board being auto-selected incorrectly when multiple boards are connected
- host-side environment installs colliding with runtime actions

## Current Limitation

The current implementation still has gaps in these areas:

- the user-facing device picker flow is not yet explicit in clients
- board inference still uses heuristics before falling back to `device_id`
- jobs are not yet presented back to clients as a fully device-partitioned queue view
- there is still a compatibility concept of one `active_device_id`

This is acceptable for the current baseline, but it is not the final engineering model.

## Required Model

## 1. Device Identity Must Be Explicit

Every connected board must have a stable runtime identifier:

- `device_id`
- `board_id`
- `variant_id`
- `transport_class`
- `connection_state`

Recommended structure:

- `device_id`
  - local control-plane identity
- `board_id`
  - e.g. `TaishanPi`, `ColorEasyPICO2`
- `variant_id`
  - e.g. `1M-RK3566`, `ColorEasyPICO2`
- `transport_class`
  - e.g. `usb-ecm`, `rp2350-single-usb`, `loader-usb`
- `transport_locator`
  - interface name, serial path, board IP, USB location, or equivalent
- `display_label`
  - short user-facing label

### Device ID rule

`device_id` must not be just `board_id`.

It should be derived from the most stable available identifiers for each board family.

Examples:

- `TaishanPi`
  - board-persisted stable UID, with current USB ECM IP held separately as `transport_locator`
- `ColorEasyPICO2`
  - USB serial number if available
  - otherwise USB location ID + runtime port path

If only a weak identifier exists, the system may generate an ephemeral `device_id`, but it must still remain stable during the current connection lifetime.

Current validated baseline:

- `TaishanPi`
  - `device_id = taishanpi::1m-rk3566::<stable_uid>`
  - `transport_locator = <current board ip>`
- `ColorEasyPICO2`
  - `device_id = coloreasypico2::coloreasypico2::<usb_serial_number>`
  - `transport_locator = <current runtime serial path>`

Planned next networking step for multiple `TaishanPi` boards:

- one point-to-point `/30` subnet per board
- host side always `.1`
- board side always `.2`
- e.g. `198.19.1.1 <-> 198.19.1.2`, `198.19.2.1 <-> 198.19.2.2`
- current compatibility fallback remains the legacy single-board pair:
  - host `198.19.77.1`
  - board `198.19.77.2`
- the older reversed pair `198.19.77.2 <-> 198.19.77.1` should be treated as stale helper/runtime output, not the target contract
- current host-side slot persistence:
  - `~/Library/development-board-toolchain/state/taishanpi-usbnet-slots.json`
- current migration behavior:
  - best-effort only
  - opt-in only through `DBT_USBNET_ENABLE_SLOT_MIGRATION=1`
- current board-side realization path:
  - boards do not infer the assigned slot by themselves
  - host-side `dbtctl` writes the chosen slot number into the board-side `network_slot` file after fetching the stable device UID
  - only slot-aware board runtimes that teach `S45usbnet` to read that file can actually come back on `198.19.<slot>.2`
  - legacy board runtimes continue to use the compatibility pair until upgraded

## 2. Status Must Return A Device List

The public control-plane status shape should evolve from:

- one collapsed current device

to:

- `devices: []`
- optional `active_device_id`
- optional compatibility summary for single-device clients

Recommended response shape:

- `devices`
  - array of connected or recently known devices
- `active_device_id`
  - currently selected device for compatibility mode
- `single_device_compat_summary`
  - only for older clients

Selection rule:

- if exactly one matching device exists, clients may auto-select it
- if multiple matching devices exist, clients must stop and ask the user to choose

## 3. All Mutating Operations Need Device-Scoped Coordination

Read-only operations may be concurrent:

- status
- capability summaries
- capability context
- log reads
- passive environment checks

Mutating operations must be serialized per device:

- flash
- reboot
- BOOTSEL transition
- save flash
- logo update
- USB ECM repair
- build-and-run
- runtime action jobs

This should be implemented as:

- per-device exclusive lock or lease

Required lease fields:

- `lease_id`
- `device_id`
- `owner_client_id`
- `owner_session_id`
- `purpose`
- `created_at`
- `expires_at`

## 4. Client Identity Must Be Passed Into Jobs

Every client should identify itself when creating jobs.

Minimum fields:

- `client_id`
- `session_id`
- `client_type`

Examples:

- `client_type = opencode`
- `client_type = gui`

These values should be attached to:

- all job records
- all lock records
- conflict responses

## 5. Conflict Behavior Must Be Deterministic

When a device is already leased by another client:

- do not silently queue behind the holder
- do not try to merge incompatible operations
- return a structured conflict response

Recommended response:

- HTTP `409` or `423`
- `error_code = device_busy`
- `device_id`
- `holder_client_id`
- `holder_session_id`
- `holder_purpose`
- `retryable`
- `summary_for_user`

Example user-facing behavior:

- `设备当前正被另一个会话占用，用于 BOOTSEL 切换。请等待当前操作结束，或显式接管该设备。`

## 6. Host-Wide Resources Need Separate Locks

Some resources are not device-scoped. They are host-scoped.

These also require coordination:

- plugin install/update
- runtime update
- board environment install
- heavy Docker compile-environment changes

These should use:

- host-global maintenance locks

Do not overload device locks for host-wide operations.

## 7. Multi-Board Operation Rules

When multiple boards are connected:

- the user may target one board explicitly
- the user may target one board family explicitly
- the user may request operations for all boards only if the tool explicitly supports broadcast behavior

Default rule:

- no broadcast by default

If the user says:

- `检查当前开发板状态`

and multiple boards are connected:

- return the device list
- ask which `device_id` or display label should be used

If the user says:

- `给 TaishanPi 刷写镜像`

and more than one TaishanPi is connected:

- stop and request a concrete device selection

## 8. Client UX Rules

### OpenCode

`OpenCode` should:

- pass `client_id/session_id`
- pass `device_id` once selected
- stop and ask when selection is ambiguous

### GUI

GUI should:

- present the full connected device list
- maintain a visible selected device
- show device-busy conflicts clearly

## 9. Engineering Rule For Tool Results

This applies to all tools, not just high-frequency ones.

Every external-facing tool should return a stable envelope:

- `ok`
- `tool_error`
- `error_code`
- `retryable`
- `summary_for_user`

This includes:

- status tools
- environment tools
- flash tools
- RP2350 tools
- plugin install/update tools
- board capability tools

No tool should fail with a silent empty response.

## 10. Recommended Next Implementation Order

1. add explicit `device_id` to status
2. add `devices[]` list to status
3. add `client_id/session_id` to job creation
4. add per-device lease manager
5. add host-global maintenance lock
6. update `OpenCode` plugin to pass and reuse `device_id`
7. update GUI to show selectable connected devices

## Source Files To Touch When Implementing

Primary control plane:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Sources/DBTAgentd/main.swift](/Users/kvell/kk-project/docker-project/docker_mac_env/dbt-agentd-project/swift-agentd/Sources/DBTAgentd/main.swift)

OpenCode plugin:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/plugins/development-board-toolchain.js](/Users/kvell/kk-project/docker-project/docker_mac_env/opencode_plugin/opencode/plugins/development-board-toolchain.js)

GUI protocol:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/TOOL_INTERACTION_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/TOOL_INTERACTION_PROTOCOL.md)

OpenCode protocol:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OPENCODE_DBT_AGENT_PROTOCOL.md](/Users/kvell/kk-project/docker-project/docker_mac_env/development-board-toolchain/docs/OPENCODE_DBT_AGENT_PROTOCOL.md)
