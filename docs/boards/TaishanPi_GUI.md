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

## Overview Page

### Status cards

The overview page currently surfaces:

- connection method
- device IP
- board ping
- SSH
- control service

### Interaction rules

- `设备 IP`
  - clickable
  - copies the board IP to clipboard
- `SSH`
  - clickable when SSH is available
  - opens a Terminal window and runs `ssh root@<board_ip>`
- all clickable status cards should use the same visual style as the rest of the control cards
- no extra hover badge or decorative dot should be shown in the top-right corner

### Device reboot

- `设备重启` is available from the connected dashboard header
- it must not open a second generic wait overlay after submission
- the action is expected to go through the local `dbt-agentd` job path

## Flash Page

The flash page remains TaishanPi-specific.

Important rule:

- GUI should submit flash-related actions to local `dbt-agentd`
- GUI should not directly own the hardware execution workflow

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
