# ColorEasyPICO2 GUI Notes

## Scope

This document describes the current GUI behavior for `ColorEasyPICO2`.

Board model:

- `ColorEasyPICO2`

Transport model:

- RP2350 single-USB workflow

## Page Structure

When `ColorEasyPICO2` is the detected board, the connected dashboard exposes these tabs:

- `总览`
- `固件`
- `通知`

It does not expose the TaishanPi-style:

- workspace release/development toggle
- generic flash page
- generic customize page

## Overview Page

### Status cards

The overview page currently surfaces:

- `连接方式`
- `当前状态`
- `串口设备`

### Intended meaning

- `连接方式`
  - derived from unified runtime status
  - examples:
    - `RP2350 单 USB`
    - `BOOTSEL USB`
- `当前状态`
  - derived from unified RP2350 state embedded in `status --json`
  - expected values:
    - `运行态`
    - `BOOTSEL`
    - `未连接`
- `串口设备`
  - only meaningful in runtime state
  - BOOTSEL state does not imply an application serial port

## Firmware Page

The firmware page is intentionally minimal.

Current retained actions:

- `刷写初始程序`
- `保存 Flash`

Removed entries:

- arbitrary UF2 path selection for the main workflow
- generic verify buttons in the main visible flow
- manual firmware A/B validation controls

### Flash initial program

- source UF2 path is fixed by installation/runtime assets
- the path should not be shown inline in the page
- the path may be shown only as a shortened hover help on the button

### Save flash

- must prompt the user for a destination path first
- then submit the flash-save action

## Current Status Dependencies

The GUI consumes these unified status fields for ColorEasyPICO2:

- `device.board_id`
- `device.interface_name`
- `device.transport_name`
- `summary`
- `device_summary`
- `rp2350.state`
- `rp2350.summary_for_user`
- `rp2350.runtime_port.device`

Important rule:

- GUI should not require a separate board-specific status command
- unified `dbtctl status --json` should already include the RP2350 state

## Current Actions

Overview actions:

- `重新检测`
- `进入 BOOTSEL`
- `恢复运行态`
- `读取日志`

Firmware actions:

- `刷写初始程序`
- `保存 Flash`

## Enable / Disable Expectations

- unavailable actions must be disabled
- disabled actions must explain why in hover help
- if a low-level function is known unstable, the GUI should disable the action rather than pretending it works

## Control-Plane Assumption

Expected chain:

- GUI -> `dbt-agentd`
- `dbt-agentd` -> `dbtctl`
- `dbtctl` -> RP2350 tools / hardware

## Maintenance Notes

- Keep ColorEasyPICO2 logic separate from TaishanPi logic.
- Do not reuse TaishanPi assumptions such as:
  - SSH
  - control service
  - USB ECM
- If new single-USB features are added, record:
  - visible page
  - state prerequisites
  - action name
  - expected runtime result
