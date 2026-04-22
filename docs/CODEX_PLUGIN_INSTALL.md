# Codex Plugin Install

This document defines the canonical install shape for the local Codex plugin `dbt-agent`.

`DBT-Agent` is the Codex-facing name. `DBT` is the short form of `Development Board Toolchain`.

## Canonical model

Codex does not get its own separate DBT runtime.

GUI, OpenCode, and Codex must all use:

- runtime: `~/Library/development-board-toolchain/runtime`
- agent: `~/Library/development-board-toolchain/agent`

The Codex plugin is only a thin wrapper installed into Codex’s own plugin directory.

## Runtime-side Codex assets

The shared runtime keeps only the install assets needed for Codex:

- `runtime/editor_plugins/codex/plugin/dbt-agent`
- `runtime/editor_plugins/codex/marketplace.json`
- `runtime/editor_plugins/codex/bin/dbt-agent-mcp-bridge`

Obsolete runtime path:

- `runtime/codex_plugin`

Do not use or restore it.

## Codex install targets

`dbtctl release install-codex-plugin` installs into Codex’s plugin root:

- preferred local marketplace root:
  - `~/.codex/.tmp/plugins`
- fallback local marketplace root:
  - `~`

So the installed plugin ends up at one of:

- `~/.codex/plugins/dbt-agent`
- `~/.codex/.tmp/plugins/plugins/dbt-agent`
- `~/plugins/dbt-agent`

And the marketplace file ends up at one of:

- `~/.codex/.tmp/plugins/.agents/plugins/marketplace.json`
- `~/.agents/plugins/marketplace.json`

## Installed plugin contents

The installed Codex plugin contains:

- `.codex-plugin/plugin.json`
- `.mcp.json`
- `skills/`
- plugin README/assets

Its `.mcp.json` must point to the shared runtime MCP bridge binary:

- `~/Library/development-board-toolchain/runtime/editor_plugins/codex/bin/dbt-agent-mcp-bridge`

It must not point to a duplicated plugin-local runtime or a plugin-local Python entry.

## UI install flow

1. Install or update the shared runtime and local `dbt-agentd`.
2. Run `dbtctl release install-codex-plugin`.
3. Restart Codex so the local marketplace metadata reloads.
4. In Codex UI, install `DBT-Agent` from the local marketplace.

## Scope

Current board families:

- `TaishanPi`
- `ColorEasyPICO2`
- `RaspberryPiPico2W`

Current skills:

- `dbt-agent`
- `rp2350`
- `taishanpi`

Current Codex-local helpers retained beyond OpenCode parity:

- `dbt_list_installed_board_plugins`
- `dbt_list_available_board_plugins`
- `dbt_search_board_plugins`

Current maintenance tools:

- `dbt_check_plugin_update`
- `dbt_update_plugin`
