# TaishanPi GUI Notes

## Scope

This document describes the current GUI behavior for the `TaishanPi` board family.

Current validated visible variant:

- `1M-RK3566`

## Page Structure

When `TaishanPi` is the detected board, the connected dashboard exposes these tabs:

- `总览`
- `刷写`
- `定制`
- `通知`

When multiple devices are connected:

- the board list page exposes a `当前激活控制设备` selector
- selecting a different device changes which board receives subsequent GUI control actions

## Overview Page

### Status cards

The overview page currently surfaces:

- connection method
- device IP
- board response
- SSH
- control service

### Interaction rules

- `设备 IP`
  - clickable
  - copies the board IP to clipboard
  - always use runtime-reported `usbnet.board_ip`; do not fall back to a hard-coded compatibility address in the GUI
- `SSH`
  - clickable when SSH is available
  - opens a Terminal window and runs `ssh root@<board_ip>`
- all clickable status cards should use the same visual style as the rest of the control cards
- no extra hover badge or decorative dot should be shown in the top-right corner
- if USB ECM is already configured but both SSH and control service are down, the GUI should show a dedicated warning that only the transport enumeration remains and the board runtime is not responding
- for that warning state, the overview should show `板端响应 = 未应答` and must not present the board as healthy just because `board.ping` still appears true

### Device reboot

- `设备重启` is available from the connected dashboard header
- it must not open a second generic wait overlay after submission
- the action is expected to go through the local `dbt-agentd` job path
- once the local-agent reboot job is accepted, the confirmation prompt may keep a short success transition to show that the reboot request has been fully submitted, then close and continue completion tracking in the background
- when the board is already in Loader / Maskrom mode, `设备重启` should stay enabled so the board can be requested back into normal runtime mode
- `切换 Loader` should use the same local-agent job style: submit quickly, release the foreground UI, and track completion in the background

## Development Environment Page

The TaishanPi development-environment panel must expose two independently detected modes:

- `Docker Linux`
  - based on Docker Desktop, the shared release image, the official workspace volume, and the runtime-managed factory image cache
- `Mac LLVM`
  - based on the Apple Silicon native LLVM SDK worktree, host LLVM tools, and the runtime staging directories used for LLVM-generated images

Current GUI rules:

- the GUI should auto-detect both modes on each refresh
- when both environments are installed, the user may manually switch which mode's detailed cards are expanded
- when only one environment is installed, the GUI should show the detected mode as fixed and should not expose a misleading mode selector
- the current manual switch is a GUI-side environment selection; it must not imply that `dev build-sync` has already switched to another local-agent toolchain profile unless that profile is actually exposed by the local control plane
- the default Mac LLVM SDK root is `/Volumes/LLVM-TSPI/sdk-tools`, unless `LLVM_TSPI_SDK_ROOT` overrides it
- the GUI should surface:
  - Docker Linux readiness
  - Mac LLVM SDK mount / case-sensitive volume state
  - Mac LLVM host-tool readiness
  - LLVM image staging readiness for `custom/current` and `custom-clang-bootprobe/current`

## Flash Page

The flash page remains TaishanPi-specific.

Important rule:

- GUI should submit flash-related actions to local `dbt-agentd`
- GUI should not directly own the hardware execution workflow

### Flash enablement

- If the board is already in Loader mode, flash actions stay enabled and are treated as direct Loader flashing.
- If the board is already in Maskrom mode, flash actions stay enabled; the runtime is expected to load `MiniLoaderAll.bin` first, then continue the flash through Loader.
- If the board is in USB ECM runtime mode, flash actions require the USB control service to be responsive so the runtime can switch the board into Loader before flashing.
- If USB ECM is present but the control service is not responsive, flash actions are disabled. The GUI should tell the user to restore the control service or manually enter Loader / Maskrom instead of submitting a flash job that will time out.

### Flash completion behavior

- For `全部` / `恢复全部` / `Boot` / `Rootfs` / `Userdata`, the GUI should treat the flash task as completed once the local-agent flash job returns success.
- If the runtime has already sent the reboot request, the GUI must not keep waiting for the board to return to USB ECM before closing the flash task UI.
- The GUI must not start any extra `post-flash USB ECM recovery` overlay for these image flash actions.
- Restoring USB ECM after reboot is a separate follow-up concern, not part of the flash completion condition.

### Long-running flash jobs

- The current local-agent flash job reports completion through `GET /v1/jobs/<job_id>`, but it may not stream detailed partition progress while the underlying runtime command is still running.
- To avoid the window appearing stuck, TaishanPi flash jobs may leave the foreground wait state and continue as a single tracked background flash task.
- For fresh flash / reboot / loader jobs, the GUI should use a denser short-window polling cadence before falling back to the normal 1-second interval.
- When the local agent returns `status_label` / `progress` / `progress_stage` / `progress_text`, the GUI should display those fields directly instead of waiting for coarse `output_tail` changes.
- While a background flash task is tracked, the GUI disables additional TaishanPi flash submissions to avoid duplicate writes.
- When that background flash task later reports success, the GUI should mark the flash task complete directly instead of waiting for USB ECM recovery.
- If the background flash task exceeds the GUI-side hard timeout, the GUI may clean up only the local `dbt-agentd` service process that this GUI instance started, including its child processes. It must not clean up model-facing `--mcp-serve` processes or unrelated agent instances.

## Current Status Dependencies

The GUI consumes these unified status fields for TaishanPi:

- `device.board_id`
- `device.display_name`
- `device.interface_name`
- `device.transport_name`
- `usb.mode`
- `usbnet.current_ip`
- `usbnet.board_ip`
- `usbnet.configured`
- `board.ping`
- `board.ssh_port_open`
- `board.control_service`
- `summary`
- `device_summary`

## Control-Plane Assumption

The GUI must treat `dbt-agentd` as the control plane.

Expected chain:

- GUI -> `dbt-agentd`
- `dbt-agentd` -> `dbtctl`
- `dbtctl` -> device

## Maintenance Notes

- Do not mix TaishanPi-specific behavior into `ColorEasyPICO2` views.
- If a new TaishanPi action is added, document:
  - visible entry point
  - enable/disable rule
  - required status fields
  - required job or action name
