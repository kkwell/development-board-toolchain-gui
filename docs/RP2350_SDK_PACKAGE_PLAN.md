# RP2350 SDK Package Plan

This document defines the recommended packaging strategy for `RP2350`-family development environments used by:

- `ColorEasyPICO2`
- `RaspberryPiPico2W`

It started as a design and implementation plan. As of version `1.0.5`, the first migration phase is already live and the current status is recorded below.

## Current Status

Implemented and verified:

- shared `RP2350RuntimeCore` archive is published and installable
- shared `RP2350SDKCore` archive is published and installable
- `dbtctl` now resolves RP2350 build context from shared `sdk_core` first
- `dbtctl` now resolves runtime-only RP2350 control from shared `runtime_core`
- `RP2350BuildOverlay/full_build` is now the shared RP2350 build overlay archive, not a duplicated compiler + `pico-sdk` package
- RP2350 offline packaging is now published as one shared family bundle instead of separate per-board bundles
- RP2350 offline bundle build now expects prebuilt environment archives and fails fast if they are missing
- `dbt-agentd` environment check/install now understands:
  - shared `minimal_runtime`
  - shared `sdk_core`
  - compatibility `full_build` overlay

Verified behavior:

- generated RP2350 runtime installs land under:
  - `~/Library/development-board-toolchain/families/rp2350/shared/board-environments/RP2350RuntimeCore/minimal_runtime/RP2350`
- generated RP2350 projects resolve `PICO_SDK_PATH` to:
  - `~/Library/development-board-toolchain/families/rp2350/shared/board-environments/RP2350SDKCore/sdk_core/RP2350/pico-sdk`
- RP2350 `minimal_runtime` install now works from the unified family bundle without any `ColorEasyPICO2/minimal_runtime` payload
- `RP2350BuildOverlay/full_build` archive size dropped from about `643M` to about `8.0K`
- unified `RP2350` offline bundle is about `656M`

Current boundary:

- `minimal_runtime` is now fully family-shared
- `full_build` is still the public install profile name, but its actual content is now:
  - shared `RP2350RuntimeCore`
  - shared `RP2350SDKCore`
  - shared `RP2350BuildOverlay`

## Why This Is Needed

Current installed environment size for `ColorEasyPICO2`:

- `minimal_runtime`: about `1.8M`
- `full_build`: about `1.6G` before the split

Current `full_build` size breakdown:

- `toolchains`: about `1.2G`
- `pico-sdk`: about `425M`
- `picotool`: about `1.7M`

Current published archive sizes after the split:

- shared `RP2350RuntimeCore/minimal_runtime`: about `528K`
- shared `RP2350SDKCore/sdk_core`: about `643M`
- `RP2350BuildOverlay/full_build` overlay: about `8.0K`

For RP2350-family boards this is wasteful because:

- `ColorEasyPICO2` and `RaspberryPiPico2W` share the same chip family
- the compiler toolchain is identical
- most of `pico-sdk` is identical
- only board metadata, CYW43 usage rules, and a few feature-specific constraints differ

## Target Outcome

The model should not generate Pico code from an unconstrained blank slate.

Instead:

1. The board knowledge layer returns exact capability-specific headers, include dirs, libraries, support headers, and protocol constraints.
2. The local build environment already has the RP2350 toolchain and SDK staged.
3. The generated user code only supplies the feature logic in `src/main.c` or `src/main.cpp`.
4. `dbtctl` compiles and links against a known, fixed environment layout.

## What Should Not Be Done

Do not reduce RP2350 support to a naive “headers + prebuilt static libs only” package.

That is not a robust primary architecture for Pico SDK because:

- library selection changes by feature profile
- `PICO_BOARD` and compile definitions affect the target graph
- `CYW43`, `lwIP`, and `BTstack` have different include/library/support-header requirements
- `pioasm`, `elf2uf2`, and related host-side tools are part of the real toolchain path
- a purely static library pack becomes brittle once feature combinations change

## Recommended Packaging Layers

Use four layers.

### 1. Shared RP2350 runtime

Purpose:

- detection
- flashing
- BOOTSEL transitions
- serial logs

Contains:

- `picotool`
- validation UF2 images
- runtime helper assets

Equivalent to current behavior of `minimal_runtime`.

### 2. Shared RP2350 SDK core

Purpose:

- make all RP2350-family boards reuse one common development base

Contains:

- ARM GNU toolchain
- shared `pico-sdk`
- required submodules:
  - `btstack`
  - `lwip`
  - `cyw43-driver`
- host tools:
  - `pioasm`
  - `elf2uf2`
  - `picotool` if needed for build-time references

This should be architecture-level, not per-board.

Recommended logical id:

- `RP2350SDKCore`

### 3. Board overlay package

Purpose:

- describe board-specific capability constraints and runtime identity

Contains:

- board metadata
- capability build-profile manifests
- initialization firmware
- support-header templates if board-specific

Examples:

- `ColorEasyPICO2`
- `RaspberryPiPico2W`

This layer should stay small.

### 4. Optional local warm build cache

Purpose:

- reduce repeated configure/build cost on a specific machine

Contains:

- generated project templates
- optional compiler cache
- optional prewarmed build trees for fixed profiles

Important:

- this is local optimization state
- do not treat it as the canonical portable SDK package

## Recommended Build Profiles

RP2350 build packaging should move to these profiles:

- `minimal_runtime`
- `sdk_core`
- `board_overlay`
- `full_build_legacy` as a fallback during migration

Where:

- `minimal_runtime` is enough for detect/flash/logs
- `sdk_core` is enough for generated code compilation
- `board_overlay` selects the correct headers/libs/rules for a board
- `full_build_legacy` remains available until the new split is proven stable

## Capability-Driven Build Contract

The authoritative build rules must come from `dbt-agentd`, not from model memory.

For RP2350-family boards, the build contract must provide:

- `required_headers`
- `required_include_directories`
- `required_link_libraries`
- `required_compile_definitions`
- `generated_support_headers`
- `capability_build_profiles`
- `feature_build_profiles`
- `runtime_protocol_requirements`

The model must choose one exact profile, for example:

- `gpio`
- `adc`
- `uart`
- `i2c`
- `spi`
- `pio`
- `multicore`
- `onboard_led`
- `wifi_bluetooth -> wifi_scan_connect`
- `wifi_bluetooth -> wireless_led_only`
- `wifi_bluetooth -> bluetooth_btstack`

## Compile Model

The generated firmware should continue to look like:

- one project
- one `src/main.c` or `src/main.cpp`
- one generated `CMakeLists.txt`
- optional generated support headers in `include/`

The environment should provide:

- `PICO_SDK_PATH`
- compiler toolchain on `PATH`
- board-specific `PICO_BOARD`

This means the model writes feature logic only.

It does not invent:

- SDK layout
- CMake import path
- board id
- CYW43 library combination
- `BTstack` include tree
- `lwipopts.h` content location

## Performance Strategy

There are two separate goals:

### Build speed

Use:

- shared installed `sdk_core`
- optional local warm build cache
- optional compiler cache

This avoids repeated environment installation and reduces rebuild time.

### Package size

Use:

- one shared `RP2350SDKCore` package
- small board overlays per board
- one RP2350 family offline bundle that carries both board plugins

This avoids duplicating:

- `toolchains`
- `pico-sdk`
- `btstack`
- `lwip`

for every RP2350-family board package.

## Why This Is Better Than Full Per-Board `full_build`

Current per-board full build packaging duplicates heavy content.

For RP2350-family boards, this is the wrong split.

The correct split is:

- chip-family-shared core
- board-specific overlay

This matches the actual engineering dependency graph.

## Migration Plan

### Phase 1

Keep current `full_build` working.

Add:

- `RP2350RuntimeCore` package definition
- `RP2350SDKCore` package definition
- board overlay definition for:
  - `ColorEasyPICO2`
  - `RaspberryPiPico2W`

### Phase 2

Change `dbtctl` to resolve build context like this:

1. `minimal_runtime` for runtime-only tasks
2. `sdk_core + board_overlay` for generated code builds
3. fall back to `full_build_legacy` only if needed

Status:

- implemented for RP2350 generated source builds
- verified against actual `CMakeCache.txt` output after `dbtctl rp2350 build_flash_source`
- verified against actual `dbtctl rp2350 detect --json` from a clean `minimal_runtime` temp install
- verified against actual `dbt-agentd /v1/environment/install` and `/v1/environment/check`

### Phase 3

Add local warm-cache support for common profiles:

- `gpio`
- `pio`
- `multicore`
- `onboard_led`
- `wifi_scan_connect`
- `bluetooth_btstack`

### Phase 4

Stop publishing duplicated per-board RP2350 `full_build` archives once the split is stable.

Status:

- functionally achieved for `ColorEasyPICO2`
- legacy profile name still remains `full_build` for compatibility, but the payload is now board-overlay-only

## Constraints

- `RaspberryPiPico2W` wireless capability should remain knowledge- and compile-profile-aware.
- Initialization firmware for `Pico 2 W` may initialize `CYW43` and blink the wireless LED, but release initialization images do not need to include full Wi-Fi connect/scan logic.
- Multiple RP2350 boards must continue to be distinguished by stable `hardware_uid`, not by transient serial paths.
- Offline packaging order must remain:
  1. `build_board_environment_bundles.sh`
  2. `build_board_offline_packages.sh`
- The offline bundler must never silently package an empty shared RP2350 directory; it now validates that the shared archive and manifest already exist.

## Immediate Recommendation

Proceed with this implementation order:

1. Introduce `RP2350SDKCore` as a shared package.
2. Introduce `RP2350RuntimeCore` as a shared runtime package.
3. Keep `ColorEasyPICO2` and `RaspberryPiPico2W` as board overlays and board-constraint layers.
4. Change `dbtctl` build-context resolution to use shared core + overlay.
5. Keep `full_build` only as a compatibility profile name.

This is the right way to reduce both repeated install cost and duplicated package size without breaking Pico SDK correctness.
