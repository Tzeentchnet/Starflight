# Starflight Genesis Recomp

Early reverse-engineering and native recompilation work for the USA/Europe
Genesis release of Starflight, built with
[segagenesisrecomp](https://github.com/mstan/segagenesisrecomp).

The first milestone targets an Apple Silicon executable that boots and supports
crew and ship persistence, starport launch, basic ship control and navigation,
and a deterministic return to Starport.
Additional deterministic regressions extend that constructor through the
landing interface to a planetary surface and sustained surface travel.
Static 68000 translations run against the framework's clean-room Genesis
runtime; uncovered dynamic targets currently use its Tier-3 interpreter floor.
The validated path now completes the starport exit sequence and reaches the
native ship playfield with `ORBIT ESTABLISHED`.

## Supported ROM

You must supply your own legally obtained ROM. ROM data, generated translations,
and save files are not distributed by this project.

| Field | Value |
| --- | --- |
| File used by the scripts | `Starflight (USA, Europe).gen` |
| Product | `GM T-50216 -00` |
| Size | 1 MiB |
| SHA-256 | `31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250` |
| CRC32 | `D550C928` |

## macOS prerequisites

- Apple Silicon Mac
- Homebrew
- CMake, Ninja, SDL2, pkg-config, LLVM, and lld
- Ghidra and OpenJDK 21 for reverse engineering

Install the dependencies with:

```sh
brew install cmake ninja sdl2 pkg-config lld ghidra
```

The macOS 27 Command Line Tools currently ship a system linker that cannot parse
the SDK's `arm64e.x1` TBD entries. The included toolchain uses Homebrew LLVM and
lld so builds remain native arm64.

## Configure, build, and run

Place the supported ROM at the repository root, then run:

```sh
scripts/configure-macos.sh
scripts/build-macos.sh
scripts/run-macos.sh
```

You may pass a different ROM path to the configure and run scripts. Configure
validates its SHA-256 before exposing it to the generated-code build.

Default player-one controls are:

| Genesis control | Keyboard |
| --- | --- |
| D-pad | Arrow keys |
| A | Z |
| B | X |
| C | C |
| Start | Return |

The runtime derives the battery-backed save name from the configured game
container and writes it beside the executable. The standard build therefore
uses `build/macos-arm64/starflight.srm`. Generated C and all build products
remain under `build/`.

Native save-state restoration is mode-aware for the validated starport path.
Corridor states resume at the per-frame corridor loop, while an in-progress
station exit resumes at its launch loop and continues into the ship playfield.

CTest runs the resume-policy test, boot smoke test, SRAM round-trip and genuine
Operations save/reload tests, plus native and forced-interpreter launch,
ship-control, navigation, return-to-Starport, planetary-landing, and
surface-exploration
regressions. The gameplay tests start from reset, construct their station-exit
and ship state with symbolic WRAM values, and do not depend on local save-state
files. The navigation path verifies sustained forward thrust while preserving
ship mode and fuel. The return path uses the in-game crew command sequence and
verifies the transition from ship mode to the Starport corridor. The landing
path selects a symbolic planet record, traverses the landing interface, and
verifies the transition to planetary mode. The surface path adds one symbolic
active-crew count and verifies that sustained travel consumes fuel while
preserving planetary mode.

The Release build preset builds the game executable only. Build the standalone
policy test before running the complete Starflight suite:

```sh
cmake --build build/macos-arm64 --target starflight_resume_policy_test
ctest --test-dir build/macos-arm64 --output-on-failure
```

Configure and run the ROM-independent framework suite with the same compiler
and linker environment:

```sh
cmake -S segagenesisrecomp/tests -B build/framework-tests -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/cmake/toolchains/macos-arm64-lld.cmake"
cmake --build build/framework-tests
env CC=/opt/homebrew/opt/llvm/bin/clang \
  CXX=/opt/homebrew/opt/llvm/bin/clang++ \
  LDFLAGS=-fuse-ld=lld \
  ctest --test-dir build/framework-tests --output-on-failure
```

## Reverse-engineering artifacts

Game-specific configuration and adapters live in `game/`. Reproducible Ghidra
annotations and discovery TOML are tracked there as the validated gameplay path
is analyzed. Local Ghidra project databases belong under `ghidra/projects/` and
are ignored.

The current annotation export is `game/annotations.csv`; its ROM-bound
provenance is recorded in `ghidra/annotations/provenance.json`.

Create the ignored local headless project with:

```sh
scripts/setup-ghidra.sh
```

The script verifies the ROM hash, imports it as `68000:BE:32:default`, creates
the Genesis work-RAM block, applies the tracked labels, and marks the reset and
interrupt vectors as functions. It refuses to overwrite an existing project.

## Current scope

This is not yet a full-game decompilation. The accepted first-milestone scope
ends after a deterministic return to Starport; a qualified post-milestone
extension reaches a planetary surface, while surface exploration and broader
game progression beyond the qualified sustained-travel checkpoint remain
exploratory. The first milestone allows observable
Tier-3 interpreter fallback outside validated paths and does not include an app
bundle, Intel support, widescreen, netplay, or a rebuildable assembly source.

The framework is licensed under PolyForm Noncommercial 1.0.0. See its
`LICENSE.md` and `THIRD-PARTY-LICENSES.md` for applicable terms and notices.
