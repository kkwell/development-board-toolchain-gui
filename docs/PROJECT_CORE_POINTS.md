# Project Core Points

## Product Identity

- Application bundle name: `DBT-Agent.app`
- In-app visible title: `Development Board Toolchain`
- Product role: local macOS menu bar GUI for development-board workflows

## Scope Of This Repository

This repository contains the macOS GUI project only.

Included:

- SwiftUI GUI source
- GUI build scripts
- GitHub Actions for build and release packaging
- GUI assets and demo materials

Not included:

- shared runtime payloads
- `dbtctl`
- `dbt-agentd`
- board plugin release payloads
- private product release orchestration

Those are installed separately under:

- `~/Library/development-board-toolchain`

## Architectural Rules

### 1. GUI is a client, not the control plane

The GUI must not become the hardware orchestration layer.

Responsibilities of the GUI:

- render status
- submit jobs
- show progress
- present install / update / plugin flows

The GUI should avoid embedding low-level hardware logic.

### 2. External calls should go through local `dbt-agentd`

The intended design is:

- GUI -> local `dbt-agentd`
- `dbt-agentd` -> local `dbtctl`
- `dbtctl` -> hardware / runtime execution

The GUI should not add new direct hardware workflows unless there is a temporary compatibility reason.

### 3. Status comes from one unified status source

Status should be derived from:

- `dbtctl status --json`

Board-specific display should be based on the returned structure, not on separate probe commands per board.

### 4. Board-specific UI logic should stay isolated

Current board families in GUI:

- `TaishanPi`
- `ColorEasyPICO2`

Their view and action logic must remain separated so changes for one board do not accidentally alter the other.

### 5. GUI releases do not bundle runtime tools

The GUI release package contains the app only.

It does not bundle:

- `dbtctl`
- `dbt-agentd`
- shared runtime assets

This is intentional.

## Current Functional Baseline

### TaishanPi

- overview dashboard
- flash / update / reboot flows
- SSH entry
- device IP copy
- runtime / service status display

### ColorEasyPICO2

- single-USB state display
- BOOTSEL / runtime state handling
- flash initial UF2
- save flash to user-selected path
- runtime log access entry

## UI Rules

- Do not add decorative status dots that overlap actionable icons.
- Interactive status cards should share a visual language with the rest of the control cards.
- If a function is unavailable, disable it and explain why in hover help.
- Avoid exposing low-level file paths directly in the main layout when a tooltip can carry the same information.

## Versioning / Publishing Rule

- Local development changes can be committed to GitHub without creating a release.
- Releases and version bumps should only happen when explicitly requested.
