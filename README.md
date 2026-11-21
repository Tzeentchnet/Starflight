# Starflight Genesis Recomp

Early reverse-engineering and native recompilation work for the USA/Europe
Genesis release of Starflight, built with
[segagenesisrecomp](https://github.com/mstan/segagenesisrecomp).

The first milestone targets an Apple Silicon executable that boots and supports
crew and ship persistence, starport launch, basic ship control and navigation,
and a deterministic return to Starport.
Additional deterministic regressions extend that constructor through the
landing interface to a planetary surface, sustained surface travel, a separate
directional-render response, and a return from the surface to orbit.
Static 68000 translations run against the framework's clean-room Genesis
runtime; uncovered dynamic targets currently use its Tier-3 interpreter floor.
The validated paths now complete the starport exit sequence, reach the native
ship playfield with `ORBIT ESTABLISHED`, return to Starport, perform one
bounded planetary landing and two qualified surface actions, then re-embark
the Terrain Vehicle and lift off to a stable orbit.

## Documentation

- [Game structure](docs/game-structure.md)
- [Data formats](docs/data-formats.md)
- [Recompilation notes](docs/recompilation-notes.md)
- [Execution plan and workstream history](docs/plan.md)

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
The framework submodule is based on upstream commit `489131d` and carries
Starflight compatibility patches that preserve the restored A7, reject unsafe
game modes, and run the setup/dispatcher continuation in both native and
forced-interpreter execution.

CTest runs the resume-policy test, boot smoke test, SRAM round-trip and genuine
Operations save/reload tests, plus native and forced-interpreter launch,
ship-control, navigation, return-to-Starport, planetary-landing, and
surface-exploration, second-surface-action, and surface-return regressions. The
gameplay tests start from reset, construct their station-exit and ship state
with symbolic WRAM values, and do not depend on local save-state files. The navigation path
verifies sustained forward thrust while preserving ship mode and fuel. The
return path uses the in-game crew command sequence and verifies the transition
from ship mode to the Starport corridor. The landing path selects a symbolic
planet record, traverses the landing interface, and verifies the transition to
planetary mode.

The first surface path adds only the symbolic active-crew count
`ActiveCrewCount` at `$FF97D3 = 1`. It holds Up for 60 frames and verifies that
fuel changes from `$00C8` to `$00C7` while planetary mode and the active-crew
count remain unchanged. Native and forced-interpreter variants use the same
recipe. Fresh forced-interpreter evidence for this path reports zero dispatch
misses, interior-label misses, unsafe-floor exits, and Tier-3 floor entries.

The second surface path reuses that reset-backed, state-free landing
constructor and holds Left for 60 frames. It verifies the complete paired
directional sprite tile-attribute words at `$FF85BC/$FF85F4` change from
`$6254/$6264` to `$7254/$7264`, while game mode remains 4,
`ActiveCrewCount` remains 1, and fuel remains `$00C8`. Static analysis shows
`$00BD1A` combines heading-derived flip flags from `$00BD0A` with patterns
`$0254/$0264`, and `$003218` emits the resulting words at SAT+4; the observed
change therefore toggles `$1000`. This qualifies a directional render-state
response, not surface displacement or a return from the surface. Fresh
forced-interpreter evidence for the 2819-frame path reports zero dispatch
misses, interior-label misses, unsafe-floor exits, and Tier-3 floor entries.

The surface-return path adds one explained constructor byte:
`TerrainVehicleStatusFlags` at `$FF9835 = 1`. Bit 0 is the terrain-vehicle
ownership state checked by `DISEMBARK`; the outfitting path also sets it when
providing a missing vehicle. After landing, the regression waits for surface
initialization, selects `DISEMBARK`, opens the Terrain Vehicle options, selects
`EMBARK`, then holds A through lift-off. Both execution modes reach stable ship
mode 2 after 5,139 frames with `ORBIT ESTABLISHED`, fuel `$00C6`, navigation
object `$07BC`, one nearby object, and nearby-object scale `$18`. The test has
no save-state, SRAM, screenshot, or raw-memory payload dependency.

The Release build preset builds the game executable only. Build the standalone
policy test before running the complete Starflight suite:

```sh
cmake --build build/macos-arm64 --target starflight_resume_policy_test
ctest --test-dir build/macos-arm64 --output-on-failure
```

To rerun the focused landing and surface preservation set:

```sh
cmake --build build/macos-arm64 --target genesisrecomp_generate_starflight
ctest --test-dir build/macos-arm64 --output-on-failure \
  -R '^(starflight_resume_policy|starflight_(planetary_landing|surface_exploration|surface_second_action|surface_return)_(native|interpreter))$'
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
provenance is recorded in `ghidra/annotations/provenance.json`. Together they
track 49 annotations: 28 code labels and 21 WRAM labels, including the four
surface-menu callbacks and neutral names for the Terrain Vehicle status byte
and paired surface tile-attribute words. The audited gameplay floor contains
76 entries: 42 runtime or accepted-path boundaries, 14 table-derived handlers,
and 20 wrappers; 47 independently emitted duplicates remain removed.
Native-code regeneration emits all 87 configured discovery entries with zero
code-gate rejections and zero unsupported code-generation diagnostics.

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
extension reaches a viable planetary surface and performs two deterministic
actions: Up consumes one fuel unit, while Left changes the paired directional
sprite tile-attribute flip state without consuming fuel. The latter assertion
does not establish world-coordinate movement. A further qualified extension
disembarks and re-embarks the Terrain Vehicle, then lifts off from planetary
mode to stable orbit. Broader game progression remains exploratory. The first milestone allows
observable Tier-3 interpreter fallback outside validated paths and does not
include an app bundle, Intel support, widescreen, netplay, or a rebuildable
assembly source.

The framework is licensed under
[PolyForm Noncommercial 1.0.0](segagenesisrecomp/LICENSE.md). Its
[additional permissions](segagenesisrecomp/PERMISSIONS.md) cover voluntary
donations, sponsorships, and advertising when access remains free. See
[THIRD-PARTY-LICENSES.md](segagenesisrecomp/THIRD-PARTY-LICENSES.md) for
applicable third-party terms and notices.
