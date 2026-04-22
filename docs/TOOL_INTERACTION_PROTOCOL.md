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

- `~/Library/development-board-toolchain`

Important paths:

- runtime command:
  - `~/Library/development-board-toolchain/runtime/dbtctl`
- local agent:
  - `~/Library/development-board-toolchain/agent/bin/dbt-agentctl`
  - `~/Library/development-board-toolchain/agent/bin/dbt-agentd`
- canonical board-family assets:
  - `~/Library/development-board-toolchain/families/rk356x/boards/TaishanPi/variants/1M-RK3566/images/{factory,custom}/current`
  - `~/Library/development-board-toolchain/families/rp2350/boards/<BoardID>/assets`

Installer expectation:

- the full product installer must provision both `runtime/` and `agent/`
- new GUI path resolution must prefer `families/...` and the new Library root first
- a GUI-only archive is not sufficient to satisfy the local control-plane dependency

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
- structured progress fields such as `progress`, `progress_stage`, `progress_text`
- output tail or error summary

Client-side polling rules:

- For `/v1/jobs/reboot` and `/v1/jobs/flash`, the GUI should use local UI-state gating plus the create-job response as the authoritative submission check. Do not add a separate remote precheck round-trip before creating the job.
- `切换 Loader` should release the foreground wait UI as soon as the local-agent job is accepted, then continue completion tracking in the background.
- `设备重启` may keep a short success transition after the local-agent job is accepted so the user can perceive that the reboot request has been fully submitted, but it must not wait for device recovery in that prompt.
- The GUI should poll more aggressively during the first few seconds of a fresh job, then fall back to the normal 1-second cadence.
- The GUI must not assume every job streams incremental output. Some local-agent jobs only update `output_tail` when the underlying runtime command exits.
- When structured progress fields are present, the GUI should prefer them over parsing `output_tail` to drive status text and progress bars.
- The GUI may detach a long-running flash job from the foreground wait UI and keep polling it in the background so the app does not appear frozen.
- While a detached flash job is still tracked, the GUI should block duplicate flash submissions for the same board flow.
- Once a flash job returns success, the GUI should treat the flash as complete. If the runtime has already issued the reboot request, the GUI must not continue waiting for the board to return to USB ECM before marking the flash task done.
- The GUI must not activate a separate post-flash `USB ECM recovery` overlay or wait state after a flash job succeeds. Any legacy post-flash recovery hook for image flashing should be treated as disabled.
- If a detached job exceeds the GUI-side timeout and the local `dbt-agentd` process was launched by the GUI itself, the GUI may terminate that GUI-owned service process tree and restart it on the next request.
- The GUI must not terminate `dbt-agentd --mcp-serve` or any unrelated local-agent process that it did not launch.

## Board-Specific Notes

### TaishanPi

- networked board model
- relies on USB ECM / SSH / control service state for normal runtime operations
- flash submission also accepts direct Loader USB
- `reboot_device` should be considered valid when the board is already in Loader / Maskrom recovery mode
- overview status should map directly from unified status fields
- if USB ECM is configured but both `board.ssh_port_open` and `board.control_service` are false, the GUI should surface this as a transport-only warning such as `USB ECM 已枚举，板端未响应`
- for that TaishanPi warning state, the GUI must not promote the board to an online/healthy state purely because `board.ping` still looks true

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
