# Data Formats

This document records the project-owned and runtime formats used by the
Starflight recompilation workflow. It does not attempt to describe every
original in-ROM table or the internal layout of Starflight save slots.

## Address and value notation

The project uses several equivalent hexadecimal styles:

- documentation and disassembly notes: `$016BAE`;
- TOML: `0x016BAE`;
- annotation CSV and input scripts: `016BAE`.

Genesis 68000 words and longwords are big-endian. Input-script `RAM16` and
`RAM32` operations therefore read and write big-endian values. ROM addresses
and CPU addresses are treated as 24-bit values by the runner.

## ROM image (`.gen`)

The `.gen` files used here are raw cartridge images, not a project-specific
container.

| Field | Required value |
| --- | --- |
| Product | `GM T-50216 -00` |
| Size | 1,048,576 bytes |
| SHA-256 | `31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250` |
| CRC32 | `D550C928` |

[`scripts/configure-macos.sh`](../scripts/configure-macos.sh) verifies the
SHA-256 and creates the ignored `game/starflight.gen` symbolic link expected by
the generator. The original ROM, the link, and all other ROM extensions listed
in [`.gitignore`](../.gitignore) remain untracked.

## Game configuration TOML

[`game/game.toml`](../game/game.toml) is the root configuration consumed by
`GenesisRecomp`.

### `[game]`

The Starflight configuration uses:

- `output_prefix`: base name for generated files and symbols;
- `jump_table_autodiscovery`: enables the framework's static table discovery;
- `discovery_files`: ordered, relative TOML fragments merged into the root
  configuration;
- `annotations`: relative path to the annotation CSV.

### `[ram_layout]`

This table emits the shared runtime's `GameRamLayout`. Starflight defines the
game-mode address, stack addresses, and explicitly sets unsupported shared
hooks to zero. The runtime treats those zero addresses as unavailable features.

### `[functions]`

Function arrays contain audited ROM addresses:

- `extra`: ordinary discovery roots included in the initial static discovery
  pass;
- `late_extra`: validated boundaries added after normal discovery reaches its
  fixed point. Their direct call and branch closure is followed without
  re-enabling speculative table detectors.

Starflight keeps the small boot set in
[`starflight_boot_floor.toml`](../game/starflight_boot_floor.toml) and the
larger evidence-driven gameplay set in
[`starflight_gameplay_floor.toml`](../game/starflight_gameplay_floor.toml).
These files are tracked inputs, not raw runtime logs.

Every promoted address must be an independently validated callable boundary.
An address reached inside an already discovered function is not a function
seed.

## Annotation CSV

[`game/annotations.csv`](../game/annotations.csv) is a headerless,
line-oriented CSV:

```csv
# comments begin with #
000200,ResetEntry,
FFC2A9,GameMode,
```

Rules used by the current importer:

- blank lines and lines beginning with `#` are ignored;
- column 1 is an unsigned hexadecimal address without a required prefix;
- column 2 is the label;
- a third empty column is accepted and retained by project convention.

The recompiler uses the file for generated labels. The headless Ghidra importer
uses the same rows, creates a `$FF0000-$FFFFFF` `WRAM` block when needed, and
applies labels to both ROM and work-RAM addresses.

## Annotation provenance JSON

[`ghidra/annotations/provenance.json`](../ghidra/annotations/provenance.json)
records:

- the ROM identity to which annotations apply;
- counts by annotation and discovery category;
- concise validation notes for important addresses and state variables.

This file is an audit record for contributors. It is not read by the build.
Keep its counts and notes synchronized when changing the annotation CSV or
audited discovery floor.

## Input-script DSL (`.input`)

Files under [`tests/inputs/`](../tests/inputs/) are plain text with one
directive per line. Blank lines are allowed, `#` starts a comment, and
directives are case-insensitive.

Common directive groups are:

| Purpose | Directives |
| --- | --- |
| Timeline | `WAIT`, `PLAYER` |
| Controls | `HOLD`, `RELEASE`, `PRESS` |
| Assertions | `ASSERT_RAM8`, `ASSERT_RAM16` |
| Blocking checks | `WAIT_RAM8`, `WAIT_RAM16` |
| State construction | `WRITE_RAM8`, `WRITE_RAM16`, `WRITE_RAM32`, `WRITE_CPU_A7` |
| Fiber control | `RESTART_GAME` |
| Local diagnostics | `SCREENSHOT`, `SAVE_STATE`, `LOAD_STATE`, `DUMP_RAM`, `DUMP_VRAM` |
| Completion | `EXIT` |

Button names are `UP`, `DOWN`, `LEFT`, `RIGHT`, `A`, `B`, `C`, and `START`.
RAM addresses and values are bare hexadecimal. Frame counts and exit codes are
normally decimal.

Example:

```text
WAIT 1200
WRITE_RAM8 FFC2A9 01
WRITE_CPU_A7 FFF000
RESTART_GAME 016BAE
WAIT 600
ASSERT_RAM8 FFC2A9 02
EXIT 0
```

`RESTART_GAME` accepts a nonzero 24-bit ROM PC. `ASSERT_RAM*` fails
immediately, while `WAIT_RAM*` blocks until the value matches. Scripts that
write memory, registers, or save states mutate simulation state and are not
valid netplay inputs.

[`tests/inputs/README.md`](../tests/inputs/README.md) identifies the
reset-backed acceptance scripts and separates them from local-state-dependent
manual probes.

## SRAM image (`.srm`)

The host persists the inclusive `$200000-$203FFF` SRAM window as a raw
16,384-byte file. The bundled macOS build writes:

```text
~/Library/Application Support/GenesisRecomp/Starflight/starflight.srm
```

`GENESIS_USER_DIR` accepts an absolute directory override. The automated tests
use `build/macos-arm64/test-user/` so they never read or modify the player's
save.

The file is loaded before guest startup and flushed during normal runtime
shutdown. The host round-trip test checks both ends of the full 16 KiB image.
The in-game save path has also been observed copying 4,096 odd-addressed bytes
through `$200001-$201FFF`, but the meaning of individual Starflight save fields
is intentionally treated as opaque unless separately characterized.

`.srm` files are user data and are ignored by Git.

## Runtime evidence TOML

When tracing is enabled, the bundled runner writes build-stamped TOML files in
the same Application Support directory as its other writable data:

| File | Meaning | May be loaded as discovery input? |
| --- | --- | --- |
| `dispatch_misses.toml` | Computed-dispatch targets with no generated function. | Only after disassembly validation. |
| `floor_coverage.toml` | In-ROM code executed by the Tier-3 floor. | Only after disassembly validation. |
| `interior_label_misses.toml` | Missing dispatch labels inside existing functions. | No; fix code generation or in-function dispatch. |
| `floor_unsafe.toml` | Misses the interpreter floor could not execute safely. | No; root-cause each entry. |

The first two expose `[functions].extra` arrays for convenient ingestion after
review. The other two deliberately use non-discovery tables. Evidence is tied
to the executable and ROM build identity; a different build rotates prior data
to `.prev.toml`. `--fresh-evidence` requests a clean evidence set for a run.

Runtime evidence is ignored and must never be promoted wholesale.

## Generated recompilation output

The normal build writes ignored files under
`build/macos-arm64/generated/starflight/`:

- `starflight_decls.h`;
- 32 `starflight_partNN.c` translation units;
- `starflight_dispatch.c`;
- `starflight_layout.c`;
- `starflight_cycles.c`;
- dispatch-audit and unresolved-jump-table diagnostics.

These files are deterministic build products of the ROM, tracked configuration,
annotations, recompiler revision, and generation options. Do not edit or commit
them.

## Local reverse-engineering artifacts

Native save states, screenshots, RAM/VRAM dumps, runtime evidence, and
[`ghidra/projects/`](../ghidra/projects/) databases are local working data.
They may help form a hypothesis, but accepted regressions must replace them
with tracked symbolic inputs and semantic assertions.
