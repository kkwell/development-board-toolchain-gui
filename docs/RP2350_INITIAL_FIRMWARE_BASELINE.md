# RP2350 Initial Firmware Baseline

This document fixes the source and release paths for the RP2350-family initialization firmware.

The current supported RP2350 board models are:

- `ColorEasyPICO2`
- `RaspberryPiPico2W`

## Purpose

The initialization firmware is the first DBT-controlled runtime image that is flashed onto a board after factory recovery or manual reset.

Its job is to provide:

- stable board-model identity via `DBT_IDENTITY`
- stable single-USB runtime command handling
- software-triggered `BOOTSEL` entry with `MSC` disabled
- a reproducible first-time board-type baseline

For `RaspberryPiPico2W`, this initialization firmware does **not** include Wi-Fi station logic, scanning logic, or CYW43 runtime control commands. Wi-Fi remains part of:

- the board knowledge base
- code generation guidance
- later user firmware implementation

It is not the same as:

- user application firmware
- temporary validation firmware under old `validation/single_usb`
- ad-hoc `/tmp` test projects

## Fixed Source Paths

The source of truth for RP2350 initialization firmware now lives in the sibling `RP2350` workspace:

- `ColorEasyPICO2`
  - source root:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/ColorEasyPICO2`
  - main source:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/ColorEasyPICO2/src/main.c`
  - project file:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/ColorEasyPICO2/CMakeLists.txt`

- `RaspberryPiPico2W`
  - source root:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W`
  - main source:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W/src/main.c`
  - project file:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W/CMakeLists.txt`
  - lwIP config:
    - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W/include/lwipopts.h`

Shared build helper:

- `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/build_initial_firmware.sh`

Default toolchain rule:

- first choice:
  - `/Users/kvell/kk-project/docker-project/RP2350/toolchains/arm-gnu-toolchain-15.2.rel1-darwin-arm64-arm-none-eabi`
- fallback:
  - `/Users/kvell/Library/development-board-toolchain/families/rp2350/shared/board-environments/RP2350SDKCore/sdk_core/RP2350/toolchains/arm-gnu-toolchain-15.2.rel1-darwin-arm64-arm-none-eabi`

The build helper now auto-selects one of these roots and prepends its `bin` directory to `PATH`.

## Fixed Build Outputs

The build outputs are fixed to:

- `ColorEasyPICO2`
  - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/ColorEasyPICO2/build/dbt_coloreasypico2_initial.uf2`

- `RaspberryPiPico2W`
  - `/Users/kvell/kk-project/docker-project/RP2350/initial_firmware/RaspberryPiPico2W/build/dbt_pico2w_initial.uf2`

These are the only UF2 outputs that should be treated as the maintained initialization images.

Do not keep pointing release logic at:

- `../RP2350/validation/single_usb/build/*.uf2`
- `/tmp/pico2w_manual/*.uf2`

Those are validation or temporary paths, not the long-term initialization baseline.

## Fixed Runtime Asset Paths

After build and packaging, the runtime assets must live at:

- `ColorEasyPICO2`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/toolkit-runtime/assets/ColorEasyPICO2/initial.uf2`

- `RaspberryPiPico2W`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/runtime/toolkit-runtime/assets/RaspberryPiPico2W/initial.uf2`

The release bundle builder copies from the fixed build outputs above into these runtime asset paths.

## Fixed Distribution Asset Paths

The exported distribution tree must also carry the same two initialization images:

- `ColorEasyPICO2`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/distribution_repo/runtime/toolkit-runtime/assets/ColorEasyPICO2/initial.uf2`

- `RaspberryPiPico2W`
  - `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/distribution_repo/runtime/toolkit-runtime/assets/RaspberryPiPico2W/initial.uf2`

## Fixed Installed Runtime Paths

Once the toolkit runtime is installed on the local machine, the deployed copies live at:

- `ColorEasyPICO2`
  - `/Users/kvell/Library/development-board-toolchain/families/rp2350/boards/ColorEasyPICO2/assets/initial.uf2`

- `RaspberryPiPico2W`
  - `/Users/kvell/Library/development-board-toolchain/families/rp2350/boards/RaspberryPiPico2W/assets/initial.uf2`

Current packaging source:

- `/Users/kvell/kk-project/docker-project/docker_mac_env/product_release/release-installer/build_runtime_bundle.sh`

Current sync command:

```bash
cd /Users/kvell/kk-project/docker-project/RP2350/initial_firmware
./build_initial_firmware.sh all --sync-assets
```

This command is now the canonical way to:

1. rebuild both initialization UF2 images
2. refresh the fixed runtime asset paths
3. refresh the exported distribution asset paths
4. refresh the already-installed runtime asset paths

## Board Identity Rule

Initialization firmware must identify itself through runtime protocol:

- `ColorEasyPICO2`
  - `board=ColorEasyPICO2`
  - `variant=ColorEasyPICO2`
- `RaspberryPiPico2W`
  - `board=RaspberryPiPico2W`
  - `variant=RaspberryPiPico2W`

Current fixed human-facing metadata:

- `ColorEasyPICO2`
  - manufacturer: `嘉立创`
  - model: `ColorEasyPICO2`
- `RaspberryPiPico2W`
  - manufacturer: `Raspberry Pi`
  - model: `Pico 2 W`

## Multi-Board Identity Rule

Board model and physical device identity must remain separated.

The current rule is:

1. Initialization firmware provides the first correct board model.
2. `dbtctl` persists `hardware_uid -> board_profile`.
3. Later reconnects use the stable `hardware_uid` first.
4. Runtime protocol is used to confirm identity when available.

This is required because:

- user firmware may change
- serial device paths such as `/dev/cu.usbmodem*` are not stable
- board model alone cannot distinguish two boards of the same type

## Pico 2 W Wi-Fi Boundary

`RaspberryPiPico2W` supports Wi-Fi and wireless LED development through the knowledge base and generated user firmware, but the maintained initialization image stays minimal and does not expose:

- `WIFI_SCAN`
- `WIFI_CONNECT`
- `WIFI_STATUS`
- CYW43 runtime control commands

## GUI / Runtime Consumption Rule

Any code that needs the default RP2350 initialization UF2 should use:

- `assets/ColorEasyPICO2/initial.uf2`
- `assets/RaspberryPiPico2W/initial.uf2`

and select between them by the current board model.

It must not hardcode `ColorEasyPICO2` as the only RP2350 initialization image.

## Maintenance Rule

When changing RP2350 initialization behavior:

1. Update the source project under `../RP2350/initial_firmware/<BoardID>`.
2. Rebuild the affected UF2.
3. Run `./build_initial_firmware.sh <BoardID|all> --sync-assets`.
4. Verify the synchronized copies under:
   - `product_release/runtime/toolkit-runtime/assets/<BoardID>/initial.uf2`
   - `product_release/distribution_repo/runtime/toolkit-runtime/assets/<BoardID>/initial.uf2`
   - `~/Library/development-board-toolchain/families/rp2350/boards/<BoardID>/assets/initial.uf2`
5. Update this document if any fixed path or naming rule changed.
