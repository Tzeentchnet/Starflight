# Recompilation Notes

This guide covers the Starflight-specific native-generation workflow. General
engine internals remain documented in
[`segagenesisrecomp/README.md`](../segagenesisrecomp/README.md).

## Prerequisites

The qualified build target is Apple Silicon macOS. Install:

```sh
brew install cmake ninja sdl2 pkg-config lld ghidra
```

Ghidra setup also expects Homebrew OpenJDK 21. The included toolchain selects
Homebrew LLVM and lld because the affected macOS Command Line Tools system
linker cannot parse current SDK `arm64e.x1` entries.

Clone recursively so the framework and its nested compiler/runtime dependencies
are present.

## Clean configure, build, and run

Place the supported ROM at the repository root, then run:

```sh
scripts/configure-macos.sh
scripts/build-macos.sh
scripts/run-macos.sh
```

Each script also accepts the ROM path where applicable. Configuration fails
before generation if the SHA-256 does not match the supported USA/Europe ROM.

## Generation pipeline

The build performs these steps:

1. [`scripts/configure-macos.sh`](../scripts/configure-macos.sh) validates the
   ROM and links it to the generator's expected
   `game/starflight.gen` path.
2. CMake configures the `macos-arm64-release` Ninja preset and builds the
   `GenesisRecomp` tool from the pinned framework submodule.
3. `genesisrecomp_add_generated_sources` runs the tool from
   [`game/`](../game/) with the equivalent inputs:

   ```text
   starflight.gen --game game.toml --output-dir <generation-stage>
   ```

4. The recompiler loads the raw ROM, root TOML, discovery fragments, and
   annotations; discovers and validates 68000 boundaries; then emits 32
   balanced C translation units plus dispatch, layout, cycle, and declaration
   files.
5. Only a successful generation is copied from the staging directory into
   `build/macos-arm64/generated/starflight/` and authorized by the generation
   stamp. A failed or interrupted run cannot leave stale C authorized.
6. [`CMakeLists.txt`](../CMakeLists.txt) links the generated sources,
   [`game/starflight_spec.c`](../game/starflight_spec.c), and the shared runner
   into `StarflightRecomp`.

All `game/*.toml`, `game/*.txt`, and `game/*.csv` files participate in CMake
freshness checking. Changing a tracked discovery input or annotation therefore
regenerates native output on the next build.

## Regenerating without rebuilding the executable

Use the generated-source target while iterating on discovery:

```sh
cmake --build build/macos-arm64 \
  --target genesisrecomp_generate_starflight
```

Useful outputs are:

```text
build/macos-arm64/generated/starflight/starflight_dispatch_audit.log
build/macos-arm64/generated/starflight/starflight.unresolved_jumptables.log
```

Generated C is diagnostic output, not source of record. Fix the ROM discovery
input, annotation, recompiler, or runtime adapter rather than editing a
generated file.

## Adding native coverage

Use this evidence-driven loop for a newly exercised path:

1. Reproduce the path with a bounded input script and semantic assertions.
2. Run the same script in native and forced-interpreter modes with fresh
   evidence.
3. Classify each reported address:
   - dispatch miss or Tier-3 floor entry;
   - interior-label miss;
   - unsafe floor exit.
4. Validate a proposed function boundary against 68000 disassembly. Runtime
   observation alone is not enough.
5. Add a true boot boundary to
   [`game/starflight_boot_floor.toml`](../game/starflight_boot_floor.toml), or a
   validated evidence-driven gameplay boundary to
   [`game/starflight_gameplay_floor.toml`](../game/starflight_gameplay_floor.toml).
6. Add a stable neutral name to
   [`game/annotations.csv`](../game/annotations.csv) when it improves shared
   reasoning, and update
   [`ghidra/annotations/provenance.json`](../ghidra/annotations/provenance.json)
   with the evidence and counts.
7. Regenerate and require zero unsupported generation diagnostics on the
   accepted path.
8. Re-run the focused native/interpreter pair and the preservation tests it can
   affect.

Do not add `interior_label_misses.toml` addresses as function roots; doing so
would split an existing function at a non-callable interior PC. Do not add
`floor_unsafe.toml` addresses until the stack, decode, or return-safety problem
is understood.

## Tier-3 and forced-interpreter modes

Starflight sets `tier3_floor_default = 1`. A native computed-dispatch miss can
therefore execute through the clean-room 68000 interpreter and be recorded for
later promotion.

This fallback is a compatibility floor, not proof of native coverage. Accepted
paths should be run both ways:

- native C with interpreter fallback available for uncovered dynamic targets;
- complete forced-interpreter execution with `GENESIS_FORCE_INTERP=1`.

CTest registers both variants for launch, ship control, navigation,
return-to-Starport, landing, and surface paths. Their properties fail on
dispatch misses, interior-label misses, or floor entries where the qualified
path requires complete coverage.

## Save-state resume contract

Starflight uses staged, mode-aware resume:

| Restored state | Resume PC |
| --- | --- |
| Mode 1, ordinary corridor | `$0130B0` |
| Mode 1, `StarportExitState == 1` and nonzero `StarportExitPhase` | `$016BAE` |
| Mode 0 or mode 2 | `$006DA4` |
| Any unsupported mode | Load is rejected |

After an active launch loop returns, the runner:

1. preserves restored A7;
2. calls setup `$01B336`;
3. continues at dispatcher/frame loop `$00B3AE`;
4. settles on redispatch `$006DA4`.

Forced-interpreter execution follows the same continuation contract. Keep these
addresses consistent across
[`game/starflight_spec.c`](../game/starflight_spec.c),
[`tests/starflight_resume_policy_test.c`](../tests/starflight_resume_policy_test.c),
and the launch/save-reload scripts.

## Validation commands

The Release preset builds only the game executable, so build the standalone
resume-policy test before running the full Starflight CTest set:

```sh
cmake --build build/macos-arm64 --target starflight_resume_policy_test
ctest --test-dir build/macos-arm64 --output-on-failure
```

For a focused landing and surface preservation pass:

```sh
cmake --build build/macos-arm64 \
  --target genesisrecomp_generate_starflight
ctest --test-dir build/macos-arm64 --output-on-failure \
  -R '^(starflight_resume_policy|starflight_(planetary_landing|surface_exploration|surface_second_action|surface_return)_(native|interpreter))$'
```

For ROM-independent framework validation:

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

Use the smallest test regex covering a change before escalating to the complete
suite.

## Ghidra reproduction

Create the ignored local project with:

```sh
scripts/setup-ghidra.sh
```

The script validates the same ROM hash, imports it as
`68000:BE:32:default`, creates the work-RAM block, applies tracked labels, and
marks reset and interrupt vectors as functions. It refuses to overwrite an
existing project.

## Reproducibility rules

- Never commit or distribute the ROM, SRAM, save states, extracted assets, or
  generated C.
- Do not make an accepted test depend on a local Ghidra project, screenshot,
  memory dump, or ignored state file.
- Prefer reset-backed symbolic constructors and semantic assertions.
- Keep Starflight-owned changes separate from reusable framework changes.
- Record new addresses with their disassembly or runtime evidence.
- Treat broader game progression as exploratory until native and
  forced-interpreter regressions qualify it.
