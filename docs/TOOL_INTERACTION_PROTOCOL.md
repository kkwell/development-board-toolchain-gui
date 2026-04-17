# Tool Interaction Protocol

This document records the current GUI-to-tool interaction contract.

This is a GUI-specific protocol document.

It does not define the OpenCode plugin contract. For OpenCode <-> `dbt-agentd`, use:

- [OPENCODE_DBT_AGENT_PROTOCOL.md](./OPENCODE_DBT_AGENT_PROTOCOL.md)

For the current stack baseline and reading order, use:

- [STACK_BASELINE_2026-04-14.md](./STACK_BASELINE_2026-04-14.md)

This protocol is expected to evolve with the private runtime and local agent. When the underlying GUI-facing tools change, this document should be updated first, then the GUI should be adapted.

## Local Install Roots

Shared local install root:

- `~/Library/Application Support/development-board-toolchain`

Important paths:

- runtime command:
  - `~/Library/Application Support/development-board-toolchain/runtime/dbtctl`
- local agent:
  - `~/Library/Application Support/development-board-toolchain/agent/bin/dbt-agentd`

## Control Plane Rule

Preferred client flow:

- GUI -> `dbt-agentd`
- `dbt-agentd` -> `dbtctl`

The GUI should not invent new low-level orchestration paths when an equivalent local-agent job already exists.

## Status Contract

Single authoritative status command:

- `dbtctl status --json`

Requirements:

- must identify the connected board type
- must include all board families in one unified result envelope
- must not require one separate status command per board family

Important fields currently consumed by the GUI:

- `summary`
- `device_summary`
- `device_id`
- `active_device_id`
- `devices[]`
- `device.board_id`
- `device.variant_id`
- `device.display_name`
- `device.interface_name`
- `device.transport_name`
- `usb.mode`
- `usbnet.current_ip`
- `usbnet.board_ip`
- `board.ssh_port_open`
- `board.control_service`
- `rp2350.state`
- `rp2350.summary_for_user`
- `rp2350.runtime_port.device`

## Local Agent Endpoints

Current local agent base:

- `http://127.0.0.1:18082`

Current GUI-relevant endpoints:

- `GET /healthz`
- `GET /v1/status/summary`
- `GET /v1/plugins/installed`
- `GET /v1/plugins/available`
- `GET /v1/plugins/search`
- `POST /v1/plugins/install`
- `POST /v1/jobs/flash`
- `POST /v1/jobs/rp2350`
- `POST /v1/jobs/runtime-action`
- `GET /v1/jobs/<job_id>`

## Multi-Device Rule

When multiple connected devices are present:

- GUI should display a selector for the active control target
- the selected target should be identified by `device_id`
- the selected `device_id` should be forwarded to local-agent actions and jobs when the endpoint supports it
- GUI should not guess a different live device once the user has explicitly selected one

## Job Model

The GUI should submit actions as jobs whenever the action can outlive a single blocking call.

Examples:

- flash
- reboot
- BOOTSEL transition
- save flash
- update-logo
- update-dtb
- build-sync-flash

Each job should provide:

- a stable `job_id`
- current state
- human-readable status label
- output tail or error summary

## Board-Specific Notes

### TaishanPi

- networked board model
- relies on USB ECM / SSH / control service state
- overview status should map directly from unified status fields

### ColorEasyPICO2

- single-USB board model
- relies on `rp2350` state embedded inside unified status
- GUI must not treat missing SSH / control service as an error for Pico2

## Adaptation Rules

When the underlying tools change:

1. Update this document.
2. Update the GUI mappings.
3. Validate both:
   - TaishanPi
   - ColorEasyPICO2
4. Only then commit the GUI changes.

## Anti-Patterns

Do not reintroduce these patterns:

- per-board standalone status commands for GUI rendering
- legacy `--service` local status path
- direct GUI fallback to deprecated local HTTP services
- board-specific shadow state that overrides unified runtime status without a documented reason
