# Starflight Genesis Recomp: Execution Plan

## Goal

Turn the current Apple Silicon proof of concept into a reproducible milestone that
another agent can build from a clean checkout and validate through:

`boot -> crew creation/load -> assignment/outfitting -> ship naming -> starport exit -> ORBIT ESTABLISHED`

The ROM remains user-supplied. Tier-3 interpreter fallback remains acceptable, but
fallback and dynamic control flow on the accepted path must remain observable and
covered by deterministic discovery inputs.

## Current baseline (2026-10-14)

### Verified

- Supported ROM:
  - Product: `GM T-50216 -00`
  - Size: 1 MiB
  - SHA-256: `31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250`
  - CRC32: `D550C928`
- Native arm64 build works with Homebrew LLVM/lld.
- Boot/title framebuffer smoke test passes.
- A fresh recursive clone configures, builds, and passes the boot smoke test after
  the verified user-supplied ROM is added.
- SRAM geometry is `$200000-$203FFF`, always visible beyond the 1 MiB ROM.
- Framework SRAM mapping test passes.
- Native and interpreter replay of the station-exit state reach the ship playfield
  and display `ORBIT ESTABLISHED`.
- Starport control-flow labels and the `$016BAE` discovery boundary are tracked.
- The project and framework are published privately:
  - `https://github.com/Tzeentchnet/Starflight`
  - `https://github.com/Tzeentchnet/Starflight-segagenesisrecomp`
- Both worktrees are clean and synchronized with their private remotes.

### Important implementation state

- Game mode is mapped to `$FFC2A9`.
- Save-state resume selection uses:
  - corridor frame loop: `$0130B0`
  - active station-exit loop: `$016BAE`
  - post-loop continuation: `$006E06`
- Saved A7 is preserved during resume.
- Forced-interpreter resume starts at the selected resume PC.
- SRAM geometry is preserved across machine-state loads.
- `$016BAE` is promoted in `starflight_gameplay_floor.toml`.

### Remaining risks

- Existing launch probes depend on ignored local `native_save_*.bin` files.
- `.srm` creation, flush, reload, and gameplay persistence are not verified.
- Scripted `EXIT` may bypass normal SRAM cleanup.
- Starport save-state selection covers only observed modes and lacks focused tests.
- The generic framework changes are available in the private mirror but have not
  been prepared for or submitted to the public upstream repository.
- Four dynamic-register JMP sites remain unresolved:
  `$039962`, `$023140`, `$02152C`, and `$005434`.
- Local save states and Ghidra projects are intentionally ignored and cannot be
  handoff dependencies.

## Dependencies and execution order

1. Stabilize and commit both repositories. **Complete.**
2. In parallel, beginning with launch validation:
   - make launch validation reproducible;
   - verify SRAM persistence;
   - deepen Ghidra annotations and discovery.
3. Extract and prepare generic framework changes for upstream review.
4. Expand gameplay qualification beyond orbit.
5. Perform clean-clone milestone qualification and packaging.

Agents must not edit the same files concurrently. Assign one owner to framework
runtime files and one owner to Starflight-owned files.

## Workstream 0: Stabilize the repositories — Complete

**Owner:** integration agent
**Dependencies:** none
**Blocks:** all other work

### Completion record

- Project stabilization baseline: `50e6a9821feabf5bac3d2daaec27be9d9219088c`.
- Framework revision: `5f718681a9206c090bcd2182903c864c987217b0`.
- Manual save-state-dependent scripts are classified in `tests/inputs/README.md`.
- The ignore policy excludes ROMs, save files, screenshots, runtime evidence,
  generated builds, and local Ghidra databases.
- No ROM, save-state, screenshot, generated build, or Ghidra database artifact is
  tracked.
- `starflight_boot_smoke` and `genesis_bus_sram` pass.
- A fresh recursive clone fetched the pinned framework and all nested submodules,
  configured, built `StarflightRecomp`, and passed `starflight_boot_smoke`.

### Steps

1. Inventory every untracked and modified file in the project and submodule.
2. Remove obsolete exploratory scripts or classify them as manual probes.
3. Confirm `.gitignore` excludes:
   - ROMs and alternate ROM containers;
   - generated build trees;
   - `.srm` and native save-state files;
   - evidence outputs and screenshots;
   - Ghidra project databases.
4. Ensure no ROM bytes, save data, extracted assets, or generated ROM-derived C are
   staged.
5. Run the baseline tests:
   - `starflight_boot_smoke`
   - `genesis_bus_sram`
6. Create logical commits for:
   - framework changes;
   - Starflight project/bootstrap;
   - launch/save-state support and annotations.
7. Record exact project and submodule commit IDs.

### Acceptance criteria

- Both worktrees are clean.
- A recursive clone builds after the user supplies the verified ROM.
- No copyrighted or local state artifacts are tracked.
- Baseline tests pass.

## Workstream 1: Make launch validation reproducible — In progress

**Owner:** Starflight runtime/test agent
**Dependencies:** Workstream 0

### Current next experiment

Inventory the save-state restore inputs used by `native_save_3.bin` and determine
the smallest symbolic CPU/WRAM recipe that reaches `$016BAE` without embedding ROM
or save data. Use that result to choose between a generated state constructor and
a deterministic traversal from reset.

### Steps

1. Replace ignored `native_save_3.bin` dependencies with one of:
   - deterministic scripted traversal from a fresh game;
   - a test-only state constructor using symbolic CPU/WRAM values;
   - a compact non-copyrightable state recipe generated at test time.
2. Do not commit raw save states or ROM-derived framebuffer images.
3. Add a launch regression proving:
   - `$016BAE` executes as a generated function boundary;
   - the non-local return continues at `$006E06`;
   - `$FFC2A9` leaves Starport mode;
   - a stable ship-playfield condition is reached.
4. Prefer semantic assertions over screenshots:
   - mode and state values;
   - execution of verified ship routines;
   - zero dispatch misses;
   - no unsafe floor fallback.
5. Run native and `GENESIS_FORCE_INTERP=1` variants from the same generated state.
6. Compare selected WRAM and control-flow outcomes.
7. Add framework tests for:
   - preserving saved A7;
   - honoring forced-interpreter resume PC;
   - preserving cartridge geometry across state load.
8. Review Starport resume edge cases and fail explicitly for unsupported states.

### Acceptance criteria

- A clean checkout runs the launch regression without local `.bin` files.
- Native and interpreter execution reach the same ship-mode checkpoint.
- No interior-label miss occurs at `$016BAE`.
- Tests fail if A7 is reset or continuation changes from `$006E06`.

## Workstream 2: Verify battery-backed SRAM

**Owner:** persistence agent
**Dependencies:** Workstream 0

### Steps

1. Identify the exact in-game operation that commits crew and ship data.
2. Test through a normal cleanup path rather than scripted `EXIT`.
3. Verify:
   - no prior `.srm`;
   - mutation of `$200000-$203FFF`;
   - dirty detection;
   - creation of a 16 KiB `.srm`;
   - loading in a second process;
   - restored crew and ship state;
   - successful launch after reload.
4. Test byte and word accesses at the first and last SRAM addresses.
5. Test out-of-range behavior.
6. Retain gated SRAM behavior for cartridges whose save range overlaps ROM.
7. Verify state loading restores SRAM content without replacing cartridge geometry.
8. Document save location, size, cleanup behavior, and limitations.

### Acceptance criteria

- A genuine save and normal shutdown produce a 16 KiB `.srm`.
- A fresh process reloads usable crew and ship state.
- SRAM, boot, and launch regressions pass.
- Results do not rely on a scripted hard exit.

## Workstream 3: Extract and upstream framework changes

**Owner:** framework maintainer agent
**Dependencies:** Workstream 0
**Coordination:** do not edit framework files concurrently with Workstream 2

### Steps

1. Separate generic engine changes from Starflight-specific policy.
2. Review:
   - `runner/video/genesis_bus.c`
   - `runner/video/genesis_bus.h`
   - `runner/video/genesis_machine.c`
   - `runner/main.c`
   - `runner/glue.c`
   - `runner/cosim_state.c`
   - related framework tests.
3. Ensure APIs and comments are cartridge-generic.
4. Test:
   - header-declared gated SRAM;
   - explicit always-mapped SRAM beyond ROM;
   - geometry preservation during state load;
   - resume A7 behavior;
   - forced-interpreter resume behavior.
5. Run the full framework suite.
6. Produce one clean framework commit suitable for an upstream PR.
7. Update the project submodule pointer.
8. Prepare an upstream summary without ROM-derived data.

### Acceptance criteria

- Framework worktree is clean at a dedicated commit.
- Full framework suite passes.
- The project pins that exact framework commit.
- The patch is generic and PR-ready.

## Workstream 4: Deepen Ghidra annotations and discovery

**Owner:** reverse-engineering agent
**Dependencies:** Workstream 0

### Steps

1. Import all tracked labels into a fresh headless Ghidra project.
2. Verify and annotate:
   - `$006DA4` Starport dispatcher;
   - `$006E06` post-Starport continuation;
   - `$013018` corridor mode;
   - `$0130B0` corridor frame loop;
   - `$016BAE` station-exit loop.
3. Annotate WRAM:
   - `$FFC2A9` mode;
   - `$FF82EC`, `$FF95B8`, `$FFB5E0` exit state;
   - `$FF9460` saved non-local return stack;
   - `$FF8332/$FF8333` controller state and edges.
4. Trace the transition through `$01B2F8` into the first stable ship loop.
5. Resolve or characterize the four dynamic-register JMP sites.
6. Audit `late_extra` entries:
   - remove obsolete entries;
   - distinguish functions from interior labels;
   - retain `$016BAE` as a verified function boundary.
7. Update provenance counts and evidence notes.

### Acceptance criteria

- Fresh Ghidra setup reproduces all tracked labels without a local `.gpr`.
- Accepted-path boundaries have meaningful symbols and evidence.
- Discovery regeneration rejects no configured entries.
- The launch path has no unexplained dispatch misses.

## Workstream 5: Expand gameplay qualification

**Owner:** gameplay coverage agent
**Dependencies:** Workstreams 1 and 2

### Steps

1. Define the next bounded path after orbit:
   - basic ship control;
   - navigation or communications;
   - land or return to Starport;
   - save and reload.
2. Traverse the path natively with evidence enabled.
3. Promote validated Tier-3 targets in small batches.
4. Compare native and interpreter state at checkpoints.
5. Add semantic regressions for each accepted mode.
6. Track remaining fallback coverage explicitly.
7. Investigate VBlank observability only if a measured timing defect depends on it.

### Acceptance criteria

- The selected path is manually and deterministically reproducible.
- Native and interpreter state agree at defined checkpoints.
- No silent dispatch miss or unsupported instruction occurs.

## Workstream 6: Package and document the milestone

**Owner:** release/integration agent
**Dependencies:** selected correctness workstreams

### Steps

1. Verify a clean Release arm64 build from a fresh checkout.
2. Confirm executable architecture and dynamic dependencies.
3. Run:
   - full framework tests;
   - Starflight boot regression;
   - launch regression;
   - SRAM lifecycle regression;
   - selected gameplay regressions.
4. Update documentation with:
   - supported ROM identity;
   - build and run commands;
   - controls;
   - save location and persistence;
   - accepted gameplay scope;
   - fallback status;
   - known limitations.
5. Record build provenance.
6. Treat a macOS `.app` bundle as a separate optional task.

### Acceptance criteria

- Another agent can reproduce the milestone without session-local files.
- Required tests pass from clean worktrees.
- Documentation matches measured behavior.
- No ROM, save state, extracted asset, or Ghidra database is distributed.

## Agent handoff requirements

Every handoff must include:

1. Project and submodule commit IDs.
2. Files changed.
3. Commands run and pass/fail status.
4. Runtime evidence generated and whether it is ignored/local.
5. New ROM addresses or WRAM variables and their validation evidence.
6. Remaining uncertainties and the next smallest falsifiable experiment.

Agents must:

- preserve unrelated worktree changes;
- avoid editing generated C directly;
- avoid committing private ROM or save artifacts;
- use semantic tests where possible;
- keep framework and Starflight commits separable;
- stop and report rather than guess at hardware behavior.

## Next milestone definition

The next milestone is complete when a fresh recursive clone, supplied only with the
verified ROM, can:

1. configure and build a native arm64 executable;
2. pass boot, launch, SRAM, and framework tests;
3. create and load crew/ship state across process restart;
4. complete the Starport exit and reach `ORBIT ESTABLISHED`;
5. reproduce tracked Ghidra annotations and discovery inputs;
6. do all of this with clean repositories and no local save-state dependency.
