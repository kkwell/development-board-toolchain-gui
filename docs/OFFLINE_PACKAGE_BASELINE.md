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

### 3. Offline bundles by board family

Contains:

- board-family plugin payloads
- family-shared or compatibility environment archives
- helper bundles where needed

Location:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages)

## Board Environment Archives

These are not the same as the final offline bundles.

Current board environment archives are under:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments)

Current shared `RP2350SDKCore` archive:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350SDKCore/dbt-rp2350-sdk-core-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350SDKCore/dbt-rp2350-sdk-core-1.0.5.tar.gz)

Current shared `RP2350RuntimeCore` archive:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350RuntimeCore/dbt-rp2350-runtime-core-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350RuntimeCore/dbt-rp2350-runtime-core-1.0.5.tar.gz)

Current shared archive size:

- `RP2350RuntimeCore`: about `528K`
- `RP2350SDKCore`: about `643M`

Current shared `RP2350BuildOverlay` archive:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350BuildOverlay/dbt-rp2350-full-build-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_environments/RP2350BuildOverlay/dbt-rp2350-full-build-1.0.5.tar.gz)

Current shared `RP2350BuildOverlay` archive size:

- `full_build` board overlay: about `8.0K`

## Current Offline Bundles

### TaishanPi

Offline bundle:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/TaishanPi/dbt-taishanpi-offline-bundle-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/TaishanPi/dbt-taishanpi-offline-bundle-1.0.5.tar.gz)

Contains:

- validated `TaishanPi` plugin payload
- compile-environment helper archive only if a matching release archive has already been built

Current helper archive source:

- current `1.0.5` bundle was built without a matching compile-environment helper archive
- last known helper archive on disk:
  - [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/compile_env_installer/out/dbt-compile-env-installer-1.0.4.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/compile_env_installer/out/dbt-compile-env-installer-1.0.4.tar.gz)

Current size:

- about `12M`

### RP2350

Offline bundle:

- [/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/RP2350/dbt-rp2350-offline-bundle-1.0.5.tar.gz](/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/board_offline_packages/RP2350/dbt-rp2350-offline-bundle-1.0.5.tar.gz)

Contains:

- validated `ColorEasyPICO2` plugin payload
- validated `RaspberryPiPico2W` plugin payload
- shared `RP2350RuntimeCore` environment archive
- shared `RP2350SDKCore` environment archive
- shared RP2350 build overlay archive published under:
  - `RP2350BuildOverlay/full_build`

Current size:

- about `656M`

## Offline Bundle Install Behavior

### TaishanPi bundle

Install script responsibilities:

- install the plugin into:
  - `~/Library/Application Support/development-board-toolchain/plugins/user/TaishanPi`
- regenerate plugin install metadata
- stage compile environment helper archives into:
  - `~/Library/Application Support/development-board-toolchain/offline-packages/TaishanPi/compile-env-installer`

### RP2350 bundle

Install script responsibilities:

- install the plugins into:
  - `~/Library/Application Support/development-board-toolchain/plugins/user/ColorEasyPICO2`
  - `~/Library/Application Support/development-board-toolchain/plugins/user/RaspberryPiPico2W`
- stage shared RP2350 SDK core archive into:
  - `~/Library/Application Support/development-board-toolchain/runtime/board_environments/RP2350SDKCore`
- stage shared RP2350 runtime core archive into:
  - `~/Library/Application Support/development-board-toolchain/runtime/board_environments/RP2350RuntimeCore`
- stage shared RP2350 build overlay archive into:
  - `~/Library/Application Support/development-board-toolchain/runtime/board_environments/RP2350BuildOverlay`
- optionally preinstall:
  - `sdk_core`
  - `minimal_runtime`
  - `full_build`
  - `all`

Installed environments land under:

- `~/Library/Application Support/development-board-toolchain/board-environments/RP2350RuntimeCore/minimal_runtime`
- `~/Library/Application Support/development-board-toolchain/board-environments/RP2350SDKCore/sdk_core`
- `~/Library/Application Support/development-board-toolchain/board-environments/RP2350BuildOverlay`

`full_build` note:

- this profile name is kept for compatibility
- its actual payload is now board overlay content only
- it now requires both:
  - shared `RP2350RuntimeCore/minimal_runtime`
  - shared `RP2350SDKCore/sdk_core`
- shared build overlay is now staged under `RP2350BuildOverlay`
- board differentiation happens through plugin metadata, initialization firmware, knowledge constraints, and runtime identity, not through separate SDK bundles

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

- keep TaishanPi separate from the RP2350 family bundle
- do not mix TaishanPi heavy Docker helper payloads into the Pico2 bundle
- use one RP2350 family offline bundle for `ColorEasyPICO2` and `RaspberryPiPico2W`
- keep shared RP2350 runtime assets in `RP2350RuntimeCore`
- keep shared RP2350 SDK assets in `RP2350SDKCore`
- keep the RP2350 build overlay shared under `RP2350BuildOverlay/full_build`
- build order must remain:
  - `build_board_environment_bundles.sh`
  - then `build_board_offline_packages.sh`
- `build_board_offline_packages.sh` must fail if the shared RP2350 archive or board archive manifests are missing
- do not collapse runtime, agent, and board offline bundles into one monolithic package
- update this document whenever offline bundle contents or install locations change
