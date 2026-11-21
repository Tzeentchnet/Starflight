# Game Structure

This document describes how Starflight is organized in this repository and how
the original Genesis program is connected to the native runtime. It is a map of
the recompilation project, not a decompilation of every original game system.

## System overview

The executable is assembled from three layers:

```text
user-supplied ROM + tracked discovery inputs
                    |
                    v
             GenesisRecomp
                    |
                    v
       generated 68000 C and dispatch data
                    |
        +-----------+-----------+
        |                       |
        v                       v
game/starflight_spec.c   shared Genesis runner
        |                       |
        +-----------+-----------+
                    |
                    v
             StarflightRecomp
```

- The ROM remains the authoritative source for original game code and data.
- The recompiler turns discovered Motorola 68000 routines into generated C.
- The game adapter supplies Starflight-specific identity, memory geometry,
  interrupt entry points, and save-state resume policy.
- The shared runner supplies the Genesis bus, VDP, audio, input, persistence,
  native dispatch, and the clean-room interpreter fallback.

## Repository map

| Path | Responsibility |
| --- | --- |
| [`game/`](../game/) | Starflight-owned recompiler configuration, discovery inputs, labels, and runtime adapter. |
| [`game/game.toml`](../game/game.toml) | Root game configuration and RAM layout. |
| [`game/starflight_boot_floor.toml`](../game/starflight_boot_floor.toml) | Audited boot/title function boundaries. |
| [`game/starflight_gameplay_floor.toml`](../game/starflight_gameplay_floor.toml) | Audited gameplay boundaries discovered beyond the static baseline. |
| [`game/annotations.csv`](../game/annotations.csv) | ROM and work-RAM labels shared by recompilation and Ghidra setup. |
| [`game/starflight_spec.c`](../game/starflight_spec.c) | Starflight implementation of the runner's `GameSpec` contract. |
| [`ghidra/`](../ghidra/) | Reproducible annotation import scripts and provenance; local project databases are ignored. |
| [`tests/inputs/`](../tests/inputs/) | Frame-based gameplay scripts used by CTest and manual probes. |
| [`tests/starflight_resume_policy_test.c`](../tests/starflight_resume_policy_test.c) | ROM-independent test of Starflight's staged resume policy. |
| [`scripts/`](../scripts/) | Supported macOS configure, build, run, and Ghidra setup entry points. |
| [`segagenesisrecomp/`](../segagenesisrecomp/) | Pinned shared recompiler and runtime submodule. |
| [`CMakeLists.txt`](../CMakeLists.txt) | Generated-source integration, executable definition, and Starflight tests. |
| [`build/`](../build/) | Ignored generated C, executables, evidence, saves, and other build products. |
| [`plan.md`](plan.md) | Detailed execution history, completed workstreams, risks, and handoff rules. |

## Cartridge and memory model

The supported cartridge image is the 1 MiB USA/Europe release with CRC32
`D550C928`. Important address spaces are:

| Range or address | Meaning |
| --- | --- |
| `$000000-$0FFFFF` | Original ROM image. |
| `$000200` | Reset entry point. |
| `$000326` | vertical-blank interrupt handler. |
| `$00033A` | horizontal-blank interrupt handler. |
| `$200000-$203FFF` | 16 KiB battery-backed SRAM window. |
| `$FF0000-$FFFFFF` | 64 KiB Genesis work RAM. |
| `$FFFFF8` | Initial supervisor stack pointer used by this game. |

The cartridge header predates the standard SRAM declaration. Starflight probes
the save window during startup, so [`starflight_spec.c`](../game/starflight_spec.c)
declares the geometry explicitly.

### Tracked game state

The reverse-engineering layer currently gives stable names to the state needed
by accepted regressions. Key examples are:

| Address | Label | Role |
| --- | --- | --- |
| `$FFC2A9` | `GameMode` | High-level mode used by dispatch and resume logic. |
| `$FF82EC` | `StarportExitState` | Distinguishes an in-progress station exit. |
| `$FF95B8` | `StarportExitPhase` | Qualifies the active station-exit loop. |
| `$FF9572` | `ShipFuel` | Fuel word checked by navigation and surface tests. |
| `$FF97D3` | `ActiveCrewCount` | Required for a viable planetary-surface state. |
| `$FF9835` | `TerrainVehicleStatusFlags` | Bit 0 records Terrain Vehicle ownership. |
| `$FFA562` | `NearbyObjectCount` | Nearby navigation-object count. |
| `$FFB84C` | `NavigationObjectId` | Current navigation object identifier. |

Observed modes on the qualified path are:

- mode 1: Starport corridor and station-exit states;
- mode 2: ship/orbit play;
- mode 4: planetary-surface play.

These names and meanings are intentionally limited to behavior supported by
disassembly and deterministic tests.

## Native execution and fallback

Static discovery emits native C functions and a generated address dispatcher.
Direct and audited dynamic targets use those functions. When supported code is
reached at an address that has not yet been emitted, Starflight enables the
Tier-3 clean-room 68000 interpreter floor by default. The floor records runtime
evidence so a validated boundary can be promoted into a later native
generation.

Native and forced-interpreter variants use the same gameplay scripts. This is
important: a passing native run alone does not establish that resume state,
register continuity, and dynamic control flow are modeled correctly.

## Save-state resume structure

The host C stack is not portable save-state data, so a loaded state restarts the
game fiber at a stable 68000 boundary selected from restored work RAM:

- Starport mode resumes at `$0130B0` for the corridor or `$016BAE` for an
  active station exit.
- Modes 0 and 2 resume through the stable dispatcher at `$006DA4`.
- Other modes are rejected rather than resumed at a guessed boundary.
- When the station-exit loop returns, the runner calls setup `$01B336`, enters
  the ship frame loop at `$00B3AE`, and then uses `$006DA4` for stable
  redispatch.
- The restored A7 value is preserved in native and forced-interpreter
  execution.

The selection policy lives in
[`game/starflight_spec.c`](../game/starflight_spec.c); its ROM-independent
contract test is
[`tests/starflight_resume_policy_test.c`](../tests/starflight_resume_policy_test.c).

## Qualified gameplay structure

The current deterministic path is:

```text
reset
  -> title / crew and ship persistence
  -> Starport corridor
  -> station exit
  -> orbit and ship controls
  -> return to Starport
  -> planetary landing
  -> bounded surface actions
  -> Terrain Vehicle disembark / embark
  -> lift-off to stable orbit
```

Each accepted gameplay constructor starts from reset and expresses its minimum
preconditions as named or documented work-RAM writes. Acceptance tests do not
depend on a developer's save state, SRAM image, screenshot, raw RAM dump, or
Ghidra project.

The path is a qualified regression surface, not evidence that the entire game
has been recompiled or characterized. Broader progression can still enter the
interpreter floor and remains exploratory.

## Source and artifact ownership

Tracked inputs:

- game configuration and discovery TOML;
- annotations and their ROM-bound provenance;
- the Starflight `GameSpec` adapter;
- deterministic input scripts and test harnesses;
- build integration and documentation.

User-supplied or generated artifacts:

- ROM images and the `game/starflight.gen` link;
- generated C and executables under `build/`;
- `.srm` saves, native save states, screenshots, dumps, and runtime evidence;
- local Ghidra project databases.

Do not commit the latter group. Regenerate native C from the verified ROM and
tracked inputs instead of editing generated files.
