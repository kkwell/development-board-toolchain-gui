# ColorEasyPICO2 GUI Notes

## Scope

This document describes the current GUI behavior for the RP2350 single-USB boards.

Board model:

- `ColorEasyPICO2`
- `RaspberryPiPico2W`

Transport model:

- RP2350 single-USB workflow

## Page Structure

When `ColorEasyPICO2` is the detected board, the connected dashboard exposes these tabs:

- `总览`
- `固件`
- `监控` only after the current runtime firmware answers the RP2350-Monitor `hello` command
- `通知`

When multiple devices are connected:

- the board list page exposes a `当前激活控制设备` selector
- selecting a different device changes which board receives subsequent GUI control actions

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

## Monitor Page

The monitor page integrates the `RP2350-Monitor` protocol for Pico 2 W style monitoring firmware.

Visible only when:

- an RP2350 board is in runtime state
- the runtime port is available as a USB CDC serial device
- `hello` confirms the firmware supports RP2350-Monitor

Transport:

- USB CDC newline-delimited JSON
- Wi-Fi TCP newline-delimited JSON on the user-provided IP and port, normally port `4242`
- USB and Wi-Fi can coexist; the GUI lets the user choose the active control channel
- 115200 baud host-side serial setup when USB is selected
- commands are serialized by the GUI to avoid corrupting the shared JSONL stream

Visible data:

- firmware version and board ID from `hello`
- Wi-Fi/AP/station state from `status`
- buffer health and dropped event counters from `status` / `buffer_status`
- configured channels from `channels`
- compact status and control-channel selection

Controls:

- `刷新状态`: runs `status`, `pins`, and `channels`
- `读取事件`: runs `events_read`
- `重新探测`: reruns `hello`
- `详细监控`: opens a separate resizable monitor window

The main monitor tab is intentionally compact. Detailed controls live in the separate monitor window so the connected dashboard does not become a dense scrolling workbench.

### Monitor Detail Window

The detail window uses segmented pages instead of one long scroll view:

- `状态`: firmware, link, Wi-Fi, buffers, channels, pin ownership, recent JSONL
- `GPIO 逻辑`: GPIO output controls plus an input-change view rendered like a small logic analyzer; starting capture immediately performs `gpio_read` so the page shows the initial high/low level
- `UART`: UART channel config, start, write, stop, release, event view
- `SPI`: SPI channel config, transfer, stop, release, event view
- `I2C`: I2C channel config, transfer, stop, release, event view
- `JSONL`: raw protocol command entry and full recent JSONL log

Each page is designed to fit the expanded window without an outer page scroll. Log text areas may scroll internally because they are data viewers.

The GUI does not assume every RP2350 initial firmware has this monitor protocol. The page is feature-gated by live protocol detection.

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

Monitor actions:

- `刷新状态`
- `读取事件`
- `重新探测`
- `详细监控`
- `配置并启动` GPIO
- `启动采集` GPIO input
- `读电平`
- `输出高`
- `输出低`
- `释放`
- UART configure/write/stop/release
- SPI configure/transfer/stop/release
- I2C configure/transfer/stop/release
- `发送命令`

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
