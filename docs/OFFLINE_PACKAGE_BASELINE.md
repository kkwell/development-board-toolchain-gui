# Offline Package Baseline

This document records the current offline packaging layout for version `1.0.5`.

## Packaging Layers

There are three different packaging layers in the current release tree.

### 1. Shared runtime

Contains:

- `dbtctl`
- shared runtime assets

Location:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime)

Primary archive:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/development-board-toolchain-runtime-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/development-board-toolchain-runtime-1.0.5.tar.gz)

### 2. Local control plane

Contains:

- `dbt-agentd`
- installed published knowledge and registry payloads

Location:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/agent](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/agent)

Primary archive:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/agent/dbt-agentd-macos-arm64-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/agent/dbt-agentd-macos-arm64-1.0.5.tar.gz)

### 3. Board-specific offline packages

Contains:

- board plugin payloads
- board-specific environment archives or helper bundles

Location:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages)

## Board Environment Archives

These are not the same as the final offline per-board bundles.

Current board environment archives are under:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments)

Current `ColorEasyPICO2` archives:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/ColorEasyPICO2/dbt-coloreasypico2-minimal-runtime-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/ColorEasyPICO2/dbt-coloreasypico2-minimal-runtime-1.0.5.tar.gz)
- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/ColorEasyPICO2/dbt-coloreasypico2-full-build-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/ColorEasyPICO2/dbt-coloreasypico2-full-build-1.0.5.tar.gz)

## Current Offline Board Bundles

### TaishanPi

Offline bundle:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/TaishanPi/dbt-taishanpi-offline-bundle-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/TaishanPi/dbt-taishanpi-offline-bundle-1.0.5.tar.gz)

Contains:

- validated `TaishanPi` plugin payload
- compile-environment helper archive

Current helper archive source:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/compile_env_installer/out/dbt-compile-env-installer-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/compile_env_installer/out/dbt-compile-env-installer-1.0.5.tar.gz)

Current size:

- about `3.2G`

### ColorEasyPICO2

Offline bundle:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/ColorEasyPICO2/dbt-coloreasypico2-offline-bundle-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/ColorEasyPICO2/dbt-coloreasypico2-offline-bundle-1.0.5.tar.gz)

Contains:

- validated `ColorEasyPICO2` plugin payload
- `minimal_runtime` environment archive
- `full_build` environment archive

Current size:

- about `465M`

## Per-Board Offline Bundle Install Behavior

### TaishanPi bundle

Install script responsibilities:

- install the plugin into:
  - `~/Library/Application Support/development-board-toolchain/plugins/user/TaishanPi`
- regenerate plugin install metadata
- stage compile environment helper archives into:
  - `~/Library/Application Support/development-board-toolchain/offline-packages/TaishanPi/compile-env-installer`

### ColorEasyPICO2 bundle

Install script responsibilities:

- install the plugin into:
  - `~/Library/Application Support/development-board-toolchain/plugins/user/ColorEasyPICO2`
- stage board environment archives into:
  - `~/Library/Application Support/development-board-toolchain/runtime/board_environments/ColorEasyPICO2`
- optionally preinstall:
  - `minimal_runtime`
  - `full_build`
  - `all`

Installed environments land under:

- `~/Library/Application Support/development-board-toolchain/board-environments/ColorEasyPICO2`

## Primary Build Scripts

- offline bundle build:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_offline_packages.sh](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_offline_packages.sh)
- environment archive build:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_environment_bundles.sh](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_board_environment_bundles.sh)
- publish tree build:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_publish_tree.sh](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/build_publish_tree.sh)
- distribution export:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/export_distribution_repo.sh](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/export_distribution_repo.sh)

## Distribution Paths

Release outputs:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages)

Mirrored distribution outputs:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/distribution_repo/board_offline_packages](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/distribution_repo/board_offline_packages)

## Rules For Future Changes

- keep per-board offline bundles separate
- do not mix TaishanPi heavy Docker helper payloads into the Pico2 bundle
- do not collapse runtime, agent, and board offline bundles into one monolithic package
- update this document whenever offline bundle contents or install locations change
