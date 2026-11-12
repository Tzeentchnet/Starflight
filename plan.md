# Starflight Genesis Recomp: Execution Plan

## Goal

Turn the current Apple Silicon proof of concept into a reproducible milestone that
another agent can build from a clean checkout and validate through:

`boot -> crew creation/load -> assignment/outfitting -> ship naming -> starport exit -> ORBIT ESTABLISHED -> basic control/navigation -> return to Starport`

The ROM remains user-supplied. Tier-3 interpreter fallback remains acceptable, but
fallback and dynamic control flow on the accepted path must remain observable and
covered by deterministic discovery inputs.

## Current baseline (2026-10-16)

The accepted milestone is complete. Qualified post-milestone extensions now
cover deterministic landing, sustained surface travel, and a second
directional surface action under the same no-local-state, native/interpreter,
and observable-fallback requirements. The deterministic surface-return
extension now disembarks and re-embarks the Terrain Vehicle, lifts off, and
reaches stable orbit under the same requirements.

### Verified

- Supported ROM:
  - Product: `GM T-50216 -00`
  - Size: 1 MiB
  - SHA-256: `31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250`
  - CRC32: `D550C928`
- Native arm64 build works with Homebrew LLVM/lld.
- Boot/title framebuffer smoke test passes.
- The accepted-milestone fresh-clone qualification configured and built after
  only the verified user-supplied ROM was added, then passed all 12 Starflight
  tests present at that revision and all 16 framework tests.
- SRAM geometry is `$200000-$203FFF`, always visible beyond the 1 MiB ROM.
- Framework SRAM mapping test passes.
- Native and forced-interpreter launch regressions start from reset, construct the
  station-exit state symbolically, continue through `$006E06`, and reach ship mode.
- Native and forced-interpreter ship-control regressions extend that constructor
  with symbolic navigation, fuel, and ship-condition state and verify that
  Right input deterministically removes the sole nearby object after orbit.
- Native and forced-interpreter navigation regressions reuse the same symbolic
  constructor and verify that sustained Up changes the projected nearby-object
  scale from `$08` to `$10` without changing ship mode or fuel.
- Native and forced-interpreter planetary-landing regressions extend the
  command-capable constructor with one symbolic nearby-object record field and
  verify the transition from ship mode to planetary mode.
- Native and forced-interpreter surface-exploration regressions add one
  symbolic active-crew count, preserve planetary mode, and verify that
  sustained surface travel consumes one fuel unit.
- Native and forced-interpreter second-surface-action regressions reuse the
  state-free landing constructor, hold Left for 60 frames, and verify the full
  paired directional sprite tile-attribute words change from `$6254/$6264` to
  `$7254/$7264` while planetary mode, active-crew count, and fuel remain stable.
- Native and forced-interpreter surface-return regressions add only the
  terrain-vehicle ownership bit at `$FF9835`, naturally traverse `DISEMBARK`
  and `EMBARK`, hold A through lift-off, and reach stable ship mode 2 with fuel
  `$00C6`, navigation object `$07BC`, and nearby-object scale `$18`.
- The launch recipe requires only three WRAM values and no local save-state,
  CPU-register, machine, VDP, screenshot, or ROM-derived payload.
- Launch evidence reports zero dispatch misses, unsafe floor exits, and
  interior-label misses.
- Starport control-flow labels and the `$016BAE` discovery boundary are tracked.
- The current annotation export and provenance track 49 labels: 28 code labels
  and 21 WRAM labels.
- The project and framework are published privately:
  - `https://github.com/Tzeentchnet/Starflight`
  - `https://github.com/Tzeentchnet/Starflight-segagenesisrecomp`
- The deterministic ship-control regression is committed in the project at
  `bb02082610e20a2d13451376bb9de78c0a7cf532`.
- The deterministic planetary-landing extension is committed in the project
  at `1fae0fe5652c34ab450b2da2f41cd389f00235dd`.
- The completed clean-clone qualification is recorded in project commit
  `348d3ddf40ad3627ea6632950547ff2986ffb4be`.
- The framework remains clean at
  `c8d0f3a83bc0fde70d549777ad865f75698a68c4` on
  `upstream/save-state-hardening`.

### Important implementation state

- Game mode is mapped to `$FFC2A9`.
- Save-state resume selection uses:
  - corridor frame loop: `$0130B0`
  - active station-exit loop: `$016BAE`
  - post-loop continuation semantics: `$006E06`, represented after resume by
    callable setup `$01B336`, ship loop `$00B3AE`, and stable redispatch
    `$006DA4`
- Saved A7 is preserved during resume.
- Forced-interpreter resume uses an A7-neutral framed execution of the selected
  resume function, then continues at the configured dispatcher.
- SRAM geometry is preserved across machine-state loads.
- `$016BAE` is promoted in `starflight_gameplay_floor.toml`.
- Input scripts support the generic `RESTART_GAME <pc>` directive for
  deterministic state construction without a serialized save.
- A genuine Operations save, 16 KiB host flush, second-process reload, symbolic
  ship/crew verification, and post-reload launch are covered by CTest.
- `$FF85BC/$FF85F4` are tracked neutrally as the paired surface directional
  sprite tile-attribute words.
- `$FF9835` is tracked as `TerrainVehicleStatusFlags`; bit 0 is the ownership
  state set by outfitting and required by the landed-ship `DISEMBARK` action.

### Remaining risks

- Legacy manual launch probes still depend on ignored local `native_save_*.bin`
  files, but milestone launch validation no longer does.
- The semantic persistence fixture uses symbolic `TEST`/`CREW` fields rather
  than a fully traversed gameplay-created roster and outfitted ship.
- The ship-control fixture was minimized from a local legacy-state comparison.
  The regression has no local-state dependency. Its navigation tuple, fuel,
  navigation-object identifier, and first two ship-system condition bytes are
  characterized and reused by the bounded navigation regression.
- Scripted `EXIT` may bypass normal SRAM cleanup; persistence regressions
  intentionally use `--max-frames` cleanup instead.
- Save-resume tests cover saved A7, native/interpreter resume-PC selection,
  explicit unsupported-mode rejection, and cartridge-geometry preservation
  across state load.
- Fresh semantic save/reload/launch evidence reports zero interior-label
  misses after promoting `$03C610`, `$03C536`, and `$03C544` as wrapper
  function entries.
- The generic framework changes are prepared and pushed to the private mirror
  on `upstream/save-state-hardening`; submission to the public upstream
  repository remains pending.
- All four dynamic-register JMP sites are statically characterized and their
  reachable targets are emitted. The finder still reports the four syntactic
  sites because it does not associate their preceding dataflow with
  `JMP (A0)`.
- The qualified Left action proves a paired sprite tile-attribute flip-state
  response, not a change in world coordinates, traversal distance, or a
  surface-return path.
- Local save states and Ghidra projects are intentionally ignored and cannot be
  handoff dependencies.

## Dependencies and execution order

1. Stabilize and commit both repositories. **Complete.**
2. **Complete:** make launch validation reproducible, verify SRAM persistence,
   and deepen Ghidra annotations and discovery.
3. **Complete for the private mirror:** extract and prepare generic framework
   changes for upstream review. Public upstream submission remains pending.
4. **Complete for the accepted milestone and current qualified extensions:**
   expand gameplay qualification beyond orbit through basic ship control,
   navigation, return to Starport, deterministic planetary landing, and two
   bounded surface actions.
5. **Complete:** perform clean-clone milestone qualification and packaging.

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

## Workstream 1: Make launch validation reproducible — Core regression complete

**Owner:** Starflight runtime/test agent
**Dependencies:** Workstream 0

### Completion record

- The `native_save_3.bin` inventory reduced the station-exit constructor to three
  symbolic WRAM writes after normal boot:
  - mode `$FFC2A9 = 1`;
  - exit state `$FF82EC = 1`;
  - exit phase `$FF95B8 = $005A`.
- No saved CPU register, machine, VDP, or raw save payload is required.
- `starflight_launch_native` and `starflight_launch_interpreter` use the same
  constructor and restart at `$016BAE`.
- Both variants reach ship mode, and the resumed loop continues at `$006E06`.
- `input_script_party`, `starflight_boot_smoke`, and both launch regressions pass.
- Runtime evidence contains zero dispatch misses, unsafe floor exits, and
  interior-label misses.
- Forced-interpreter resume now detects the function return with framed,
  A7-neutral execution instead of interpreting through an invalid return target.
- Both launch variants seed saved A7 with `$FFF000` and require the resumed
  `$016BAE` loop to report that exact value before continuing at `$006E06`.
- `starflight_resume_policy` covers corridor, active station-exit, post-launch,
  and explicit unsupported-mode selection. Unsupported modes now reject the
  state instead of silently falling back to a Starport entry point.
- Quickstate and rollback loads now share explicit SRAM-geometry preservation:
  loaded SRAM bytes and runtime enable state are retained, while the current
  cartridge's configured base, end, size, presence, and always-mapped policy
  remain authoritative.
- `genesis_bus_sram` covers a conflicting saved geometry and verifies that
  Starflight's `$200000-$203FFF` 16 KiB mapping survives while saved SRAM bytes
  and enable state load. The focused test passes in `0.26` seconds.
- The runner rebuilds successfully, and post-change
  `starflight_launch_native` and `starflight_launch_interpreter` pass in
  `30.25` and `30.06` seconds.

### Current next experiment

**Complete:** the validated generic framework changes were separated from
Starflight-specific policy, with the original hardening at `e2046ac` and staged
resume dispatch at `a35c88f`, and pushed to the private mirror. Active
investigation has moved to Workstream 4.

### Steps

1. **Complete:** Replace ignored `native_save_3.bin` dependencies with one of:
   - deterministic scripted traversal from a fresh game;
   - a test-only state constructor using symbolic CPU/WRAM values;
   - a compact non-copyrightable state recipe generated at test time.
2. **Complete:** Do not commit raw save states or ROM-derived framebuffer images.
3. **Complete:** Add a launch regression proving:
   - `$016BAE` executes as a generated function boundary;
   - the non-local return continues at `$006E06`;
   - `$FFC2A9` leaves Starport mode;
   - a stable ship-playfield condition is reached.
4. **Complete:** Prefer semantic assertions over screenshots:
   - mode and state values;
   - execution of verified ship routines;
   - zero dispatch misses;
   - no unsafe floor fallback.
5. **Complete:** Run native and `GENESIS_FORCE_INTERP=1` variants from the same
   generated state.
6. **Complete:** Compare selected WRAM and control-flow outcomes.
7. **Complete:** Add framework tests for:
   - **Complete:** preserving saved A7;
   - **Complete:** honoring forced-interpreter resume PC;
   - **Complete:** preserving cartridge geometry across state load.
8. **Complete:** Review observed Starport resume modes and fail explicitly for
   unsupported mode values.

### Acceptance criteria

- **Satisfied:** The launch regression has no local `.bin` dependency.
- **Satisfied:** Native and interpreter execution reach the same ship-mode
  checkpoint.
- **Satisfied:** No interior-label miss occurs at `$016BAE`.
- **Satisfied:** Continuation changes from `$006E06` or loss of saved A7
  `$FFF000` fail both launch variants.
- **Satisfied:** Launch regressions pass from the qualified fresh recursive
  clone at the recorded project and framework revisions.

## Workstream 2: Verify battery-backed SRAM

**Owner:** persistence agent
**Dependencies:** Workstream 0

### Progress record

- `starflight_sram_roundtrip` now starts without an `.srm`, writes byte and word
  sentinels at `$200000`, `$200002`, `$203FFE`, and `$203FFF`, waits for the
  normal autosave path, and exits through `--max-frames` cleanup rather than
  scripted `EXIT`.
- The first process creates exactly 16 KiB at
  `build/macos-arm64/starflight.srm`; a second process loads all 16 KiB and
  verifies the sentinels before guest startup can alter SRAM.
- The round-trip fixture covers first/last byte, first/last word, and
  out-of-range writes through the real bus; `genesis_bus_sram` retains its
  always-mapped and out-of-range mapping checks.
- The exact commit action is Operations (`START`) -> `SAVE AS GAME 1` (`A`).
  A runtime trace observed 4,096 odd-byte writes across `$200001-$201FFF` from
  `$037AA0`/`$037C94`, followed by the normal 16 KiB host flush.
- `starflight_sram_game_save` reproduces that genuine game action from the
  symbolic corridor constructor, without a local save-state dependency or
  scripted `EXIT`.
- The save regression now assigns symbolic `TEST` ship and `CREW` crew names.
  A second process selects GAME 1 from the title menu, verifies both canonical
  WRAM fields, and launches through `$016BAE` to ship mode.
- Focused validation passes:
  - `genesis_bus_sram`;
  - `starflight_sram_roundtrip`;
  - `starflight_sram_game_save`.
- Regeneration emits `func_03C610`, `func_03C536`, and `func_03C544`.
  Fresh semantic save/reload/launch evidence records `entries: 0` in
  `interior_label_misses.toml`.
- Post-promotion preservation validation passes:
  - `starflight_sram_game_save` in `58.83` seconds;
  - `starflight_sram_roundtrip` in `21.41` seconds;
  - `starflight_launch_native` in `30.06` seconds;
  - `starflight_launch_interpreter` in `30.07` seconds.

### Steps

1. **Complete:** Identify the exact in-game operation that commits crew and ship data.
2. **Complete:** Test through a normal cleanup path rather than scripted `EXIT`.
3. **Complete:** Verify:
   - **Complete:** no prior `.srm`;
   - **Complete:** mutation of `$200000-$203FFF`;
   - **Complete:** dirty detection;
   - **Complete:** creation of a 16 KiB `.srm`;
   - **Complete:** loading in a second process;
   - **Complete:** restored symbolic crew and ship state;
   - **Complete:** successful launch after reload.
4. **Complete:** Test byte and word accesses at the first and last SRAM addresses.
5. **Complete:** Test out-of-range behavior.
6. Retain gated SRAM behavior for cartridges whose save range overlaps ROM.
7. **Complete:** Verify state loading restores SRAM content without replacing
   cartridge geometry.
8. Document save location, size, cleanup behavior, and limitations.

### Acceptance criteria

- A genuine save and normal shutdown produce a 16 KiB `.srm`.
- **Satisfied:** A fresh process reloads symbolic crew and ship state.
- SRAM, boot, and launch regressions pass.
- Results do not rely on a scripted hard exit.
- **Satisfied:** The extended save/reload/launch path has zero interior-label
  misses.

## Workstream 3: Extract and upstream framework changes

**Owner:** framework maintainer agent
**Dependencies:** Workstream 0
**Coordination:** do not edit framework files concurrently with Workstream 2

### Steps

1. **Complete:** Separate generic engine changes from Starflight-specific policy.
2. **Complete:** Review:
   - `runner/video/genesis_bus.c`
   - `runner/video/genesis_bus.h`
   - `runner/video/genesis_machine.c`
   - `runner/main.c`
   - `runner/glue.c`
   - `runner/cosim_state.c`
   - related framework tests.
3. **Complete:** Ensure APIs and comments are cartridge-generic.
4. **Complete:** Test:
   - header-declared gated SRAM;
   - explicit always-mapped SRAM beyond ROM;
   - geometry preservation during state load;
   - resume A7 behavior;
   - forced-interpreter resume behavior.
5. **Complete:** Run the full framework suite.
6. **Complete:** Produce one clean framework commit suitable for an upstream PR.
7. **Complete:** Update the project submodule pointer.
8. **Complete:** Prepare an upstream summary without ROM-derived data.

### Extraction record

- The uncommitted framework delta is confined to 11 generic runner/test files
  and separates into three reviewable units:
  1. resume-PC resolution, unsupported-mode rejection, saved-A7 continuation,
     and framed forced-interpreter resume;
  2. generic `WRITE_CPU_A7` and `RESTART_GAME` deterministic-script directives;
  3. SRAM geometry preservation across quickstate and rollback loads.
- Starflight-specific resume mappings, symbolic fixtures, ROM addresses, and
  semantic save/load scripts remain in the game workspace and are not part of
  the framework delta.
- Geometry preservation depends on private framework commit `4af9a8e`
  (`Support always-mapped cartridge SRAM`). Private commit `5f71868` only
  changes canonical submodule URLs and is unrelated to the runtime patch.
- The full framework suite passes all 16 tests. The initial
  `generated_input_paths` run selected the host's malformed macOS 27 SDK;
  rerunning it with the same macOS 15.4 SDK used by the game build passed.
- The game runner integration build succeeds after the extraction cleanup.
- Dedicated branch `upstream/save-state-hardening` contains the original
  `e2046ac` (`Harden cartridge save-state handling`) commit and follow-up
  `a35c88f` (`Support staged resume dispatch`).
- `a35c88f` is pushed to
  `origin/upstream/save-state-hardening` in the private framework mirror.
- The clean upstream tree differs from the validated private `df73e8a` tree
  only by excluding the unrelated `.gitmodules` URL change.
- Project commit `acb6f4a` pins `segagenesisrecomp` at `a35c88f` and maps the
  post-launch continuation to callable setup, ship-loop, and redispatch
  entries.
- Starflight `main` is pushed through `8a1e558` on `origin/main`; the pushed
  history also contains plan/extraction commit `9618212`.

### Upstream summary

- Support cartridge SRAM ranges that are permanently mapped beyond ROM.
- Preserve current cartridge SRAM geometry while restoring saved SRAM bytes
  and runtime mapping state in quickstate and rollback loads.
- Centralize resume-PC selection and allow games to reject restored modes that
  cannot resume safely.
- Preserve the saved stack pointer through native and framed-interpreter resume
  paths.
- Add cartridge-neutral scripting and regression coverage for deterministic
  resume construction.
- Support a callable one-time post-resume setup, callable main loop, and stable
  redispatch entry without invoking an interior continuation as a function.

### Current status

The framework track is complete and remains ready for public upstream
submission. The active reverse-engineering experiment is tracked in Workstream
4 below.

### Acceptance criteria

- **Satisfied:** Framework worktree is clean at dedicated commit `a35c88f`.
- **Satisfied:** The full framework suite passed at `e2046ac`; the staged
  dispatch follow-up passes the focused Starflight resume-policy and
  native/interpreter navigation regressions.
- **Satisfied:** Project commit `acb6f4a` pins `a35c88f`.
- **Satisfied:** The patch is generic and PR-ready.

## Workstream 4: Deepen Ghidra annotations and discovery

**Owner:** reverse-engineering agent
**Dependencies:** Workstream 0

### Steps

1. **Complete:** Import all tracked labels into a fresh headless Ghidra project.
2. Verify and annotate:
   - `$006DA4` Starport dispatcher;
   - `$006E06` post-Starport continuation;
   - `$013018` corridor mode;
   - `$0130B0` corridor frame loop;
   - `$016BAE` station-exit loop.
3. **Complete:** Annotate WRAM:
   - `$FFC2A9` mode;
   - `$FF82EC`, `$FF95B8`, `$FFB5E0` exit state;
   - `$FF9460` saved non-local return stack;
   - `$FF8332/$FF8333` controller state and edges.
4. **Complete:** Trace the ship transition, characterize `$01B2F8`, and
   identify the first stable ship loop.
5. **Complete:** Resolve or characterize the four dynamic-register JMP sites.
6. **Complete:** Audit `late_extra` entries:
   - remove obsolete entries;
   - distinguish functions from interior labels;
   - retain `$016BAE` as a verified function boundary.
7. **Complete:** Update provenance counts and evidence notes.

### Dynamic-JMP characterization record

- `$039962` is `JMP (A0)` at the end of `$0398C4`.
- `$0398C4` scans 13 fixed 12-byte region-action records beginning at
  `$039964`; when coordinate bounds match, `$03995E` loads A0 from the final
  longword of the selected record.
- The bounded handler set is:
  `$039C68`, `$039C82`, `$039C9C`, `$039CCC`, `$039CE6`, `$039D00`,
  `$039D30`, `$039D38`, `$03A306`, `$03A310`, `$03A31A`, `$03A324`, and
  `$03A33E`.
- All 13 targets disassemble as valid handler entries and are now explicit
  table-derived `late_extra` seeds. Regeneration emits all 115/115 configured
  entries with zero code-gate rejections.
- `starflight_sram_game_save` passes after promotion in `58.82` seconds with
  zero semantic lifecycle regressions.
- `$023140` is `JMP (A0)` at the end of `$02311A`.
- `$02311A` reads the selector at `$FF9AAC`, scales it by four, and uses the
  15-entry pointer table at `$023144` to choose a six-byte `(key, handler)`
  record list. The selector is sourced from byte 3 of the 230 fixed world
  records at `$01A8E0`; those records contain only selector values 1 through
  13.
- Selectors 2 through 13 point directly to the sentinel at `$023180`.
  Selector 1 points to two records for keys `$0046` and `$0047`, and both
  records contain the same handler `$023190`.
- `$023190` disassembles as a valid function entry and is now an explicit
  table-derived `late_extra` seed.
- Regeneration emits all 116/116 configured entries with zero code-gate
  rejections, and `starflight_sram_game_save` passes after promotion in
  `58.90` seconds.
- The finder still reports all four syntactic sites because its manual
  jump-table support only associates recognized indexed-PC dispatch patterns,
  not these record-scan dataflows.
- `$02152C` is `JMP (A0)` at the end of `$021504`.
- `$021504` reads the same selector at `$FF9AAC`, scales it by four, and loads
  A0 directly from the 15-entry long-pointer table at `$021530`. The fixed
  world records constrain the live selector to values 1 through 13.
- The bounded reachable handler set is `$02156C`, `$02156E`, `$0219EE`,
  `$0219F0`, and `$02206A`. Every target is already an independently
  discovered function entry, so this site requires no additional
  `late_extra` seed.
- `$005434` is `JMP (A0)` at the end of `$005422`.
- `$005422` sign-extends the mode byte at `$FF8780`, scales it by four, and
  loads A0 from the long-pointer table at `$0055F8`.
- `$FF8780` is written only as zero or from the fixed selector lists at
  `$005988`, `$00598A`, and `$005992`. Their bounded output set is 0 through
  6, selecting `$005614`, `$005624`, `$005680`, `$00561A`, `$00568C`,
  `$005CE2`, or `$005DFC`.
- All seven handlers are already independently discovered function entries,
  so this site requires no additional `late_extra` seed.
- All four dynamic-register JMP sites are now characterized. The unresolved
  finder log remains a syntactic limitation rather than an unknown reachable
  target set.

### Discovery-floor audit record

- A static-only regeneration omitted all 103 gameplay `late_extra` seeds while
  retaining the normal root and boot floors. It emitted 47 of those gameplay
  entries independently and proved that 56 still require explicit floor
  coverage.
- The 47 static duplicates were removed. The retained floor contains 27
  runtime-observed or accepted-path boundaries, 14 fixed table-derived
  handlers, and 15 runtime-observed wrapper entries.
- `$016BAE` remains an explicit accepted-path function boundary. `$023190` and
  all 13 handlers reached through `$039962` remain explicit table-derived
  seeds.
- Annotation provenance still matches all 21 CSV labels and now records the
  gameplay-floor category counts and the 47 removed duplicates.
- Regeneration emits all 69/69 configured entries with zero code-gate
  rejections and preserves the exact 1015 discovered / 1141 final function
  counts. Unsupported code-generation diagnostics remain zero.
- `starflight_sram_game_save`, `starflight_launch_native`, and
  `starflight_launch_interpreter` all pass after the reduction.

### Ghidra reproducibility record

- Ghidra 12.1.4 with OpenJDK 21 imported the verified ROM into a newly created
  headless project using `scripts/setup-ghidra.sh`'s command sequence.
- `ImportStarflightAnnotations.java` verified the ROM SHA-256, created the WRAM
  block, imported all 21 tracked code labels, and saved the project
  successfully without using the ignored local project database.
- After adding the seven validated WRAM labels, a second fresh import reported
  all 28 annotations and saved successfully. The WRAM set covers game mode,
  three Starport exit-state fields, the non-local return stack, and controller
  state/edge bytes.
- After adding the three ship-loop symbols below, a third fresh import reported
  all 31 annotations and saved successfully.
- After adding the five ship-state symbols below, a fourth fresh import reported
  all 36 annotations and saved successfully.

### Ship-loop characterization record

- Static control flow shows two distinct ship-mode entries:
  - the normal mode-2 dispatcher path at `$006E1E` calls `$01B2F8`, which
    preserves `$FF8AA6/$FF8AA8` around the shared initializer;
  - the accepted Starport launch continuation at `$006E06` calls `$01B336`,
    which clears `$FFA5E8` before entering the same initialization sequence.
- Both return paths tail-call `$00B3AE`. Its back-edge at `$00B552` returns to
  `$00B3AE`, making it the first stable main frame loop after ship
  initialization.
- Forced-interpreter executed-PC evidence from the deterministic launch
  contains `$006E06`, `$01B336`, `$01B340`, `$00B3AE`, and `$00B552`.
  `$01B2F8` is absent, correcting the earlier assumption that the accepted
  launch transition executed that entry.
- The evidence run completed 1810 frames with zero dispatch misses,
  interior-label misses, unsafe-floor exits, or hybrid interpreter calls.
- `$00B3AE`, `$01B2F8`, and `$01B336` now have neutral symbols reflecting
  their validated roles.
- Regeneration preserves the 1015 discovered / 1141 final function counts,
  and both native and forced-interpreter launch regressions pass with the new
  annotations.

### Surface annotation follow-up

- Static analysis identified `$FF85BC` and `$FF85F4` as paired directional
  sprite tile-attribute words. `$00BD1A` combines heading-derived flip flags
  from `$00BD0A` with base patterns `$0254/$0264`, and `$003218` emits the
  resulting words at SAT+4.
- The two WRAM locations are tracked with the neutral symbols
  `SurfaceDirectionalSpriteTileAttribute0` and
  `SurfaceDirectionalSpriteTileAttribute1`.
- The current annotation export contains 49 labels: 28 code labels and 21 WRAM
  labels. The corrected gameplay-floor provenance records 71 entries: 42
  runtime or accepted-path boundaries, 14 table-derived handlers, and 15
  wrappers, with 47 static duplicates removed.
- The later surface-return extension added four validated dynamic callback
  boundaries to `game/starflight_gameplay_floor.toml`. Regeneration emits all
  82/82 configured entries with zero code-gate rejections and zero unsupported
  code-generation diagnostics.

### Workstream handoff

**Complete:** Workstream 5 selected basic ship control, added matching native
and forced-interpreter semantic regressions, then extended the qualified path
through navigation, landing, two surface actions, and the deterministic return
from planetary mode to orbit.

### Acceptance criteria

- Fresh Ghidra setup reproduces all tracked labels without a local `.gpr`.
- Accepted-path boundaries have meaningful symbols and evidence.
- Discovery regeneration rejects no configured entries.
- The launch path has no unexplained dispatch misses.

## Workstream 5: Expand gameplay qualification

**Owner:** gameplay coverage agent
**Dependencies:** Workstreams 1 and 2

### Progress record

- `starflight_surface_second_action.input` starts from reset and reuses the
  state-free landing constructor with `ActiveCrewCount` at `$FF97D3 = 1`.
  After reaching game mode 4, it holds Left for 60 frames.
- The regression asserts the complete paired directional sprite tile-attribute
  words at `$FF85BC/$FF85F4`: `$6254/$6264` before input and `$7254/$7264`
  afterward. Game mode remains 4, `ActiveCrewCount` remains 1, and fuel at
  `$FF9572` remains `$00C8`.
- The `$1000` delta is consistent with the static surface-render trace:
  `$00BD1A` combines heading-derived flip flags from `$00BD0A` with patterns
  `$0254/$0264`, then `$003218` emits both words at SAT+4. This checkpoint
  qualifies a directional render-state response; it does not establish
  surface-coordinate movement.
- CMake registers native and forced-interpreter variants with a 3000-frame
  limit, 90-second timeout, staged-resume pass expression, and shared
  `starflight_runtime` resource lock.
- The first six-test preservation run covering planetary landing, surface
  exploration, and the second action in both execution modes passed in
  `278.19` seconds. After replacing partial assertions with full-word
  assertions, the second-action pair passed again in `94.04` seconds.
- Final focused validation on 2026-10-16 passed all seven selected tests in
  `278.16` seconds: resume policy in `0.00`, landing native/interpreter in
  `45.03/45.02`, surface exploration in `47.02/47.03`, and the second action
  in `47.03/47.04` seconds. The command was:
  `ctest --test-dir build/macos-arm64 --output-on-failure -R
  '^(starflight_resume_policy|starflight_(planetary_landing|surface_exploration|surface_second_action)_(native|interpreter))$'`.
- The final 2819-frame forced-interpreter run refreshed the ignored local
  evidence files under `build/macos-arm64/`; they contain zero dispatch misses,
  interior-label misses, unsafe-floor exits, and Tier-3 floor entries.
- `cmake --build build/macos-arm64 --target
  genesisrecomp_generate_starflight` passes; the final check found the
  82/82-generated target current (`ninja: no work to do`). The integrated
  regeneration reported zero gate rejections and zero unsupported diagnostics.
- `git diff --check` passes for the integrated worktree.
- The current tracked annotation total is 49. Provenance records the
  71-entry gameplay floor (`42` runtime/boundary, `14` table-derived,
  `15` wrapper).
- The original landing checkpoint was not a viable exploration state: with
  `$FF97D3 = 0`, the surface appeared at frame 2699 but entered the
  crew-killed path through `$03C66E` by frame 2819 while leaving game mode 4
  stale.
- A legacy local state was used only as a discovery oracle. Its 69 nonzero
  bytes in `$FF9782-$FF9835` prevented the fatal transition; record- and
  byte-level reduction isolated the sole required field as
  `$FF97D3 = 1`.
- Static generated-code inspection shows `$009E4A` branches away from the
  planetary path when `$FF97D3` is zero, while `$01813E` decrements it.
  The field is tracked neutrally as `ActiveCrewCount`.
- With that one added symbolic byte, holding Up for 60 frames preserves
  planetary mode and the active-crew count while changing ship fuel from
  `$00C8` to `$00C7`.
- `starflight_surface_exploration_native` and
  `starflight_surface_exploration_interpreter` pass in `47.23` and `47.02`
  seconds.
- Four post-landing Tier-3 entries and four later surface-return callbacks were
  promoted. Regeneration emits all 82/82 configured entries with zero
  code-gate rejections and reports zero unsupported code-generation
  diagnostics.
- Fresh forced-interpreter evidence over 2819 frames reports zero dispatch
  misses, interior-label misses, unsafe-floor exits, and Tier-3 floor entries.
- Post-change `starflight_planetary_landing_native` and
  `starflight_planetary_landing_interpreter` continue to pass in `45.01` and
  `45.03` seconds.
- A fresh Ghidra 12.1.4 headless import reproduced and saved the 42 annotations
  tracked at that stage, including `ActiveCrewCount`, without using the ignored local
  project.
- Project implementation commit:
  `56d58b3aadf4c4b94a2791148684ff1a231f8aee`
  (`Add deterministic surface exploration regression`).
- Post-milestone planetary landing work reproduced the real interaction as C,
  Down, A, A to enter the landing interface, followed by sustained Down and A
  to land; the earlier record omitted those final interface controls.
- The Starport constructor derives navigation object `$07CB` from the selected
  nearby-object record. Setting that record's one-based orbital slot at
  `$FFA6A8` to `$0015` immediately before choosing Land instead derives
  `$07BC`, enters the landing interface, and reaches game mode 4 on the
  planetary surface.
- The first successful native probe reached the surface at frame 2699 with
  zero dispatch misses or interior-label misses.
- Seven observed landing-interface Tier-3 entries were promoted into the
  gameplay floor. Regeneration emits all 76/76 configured entries with zero
  code-gate rejections.
- `starflight_planetary_landing_native` and
  `starflight_planetary_landing_interpreter` pass in `45.34` and `45.03`
  seconds. Fresh forced-interpreter evidence reports zero dispatch misses,
  interior-label misses, and Tier-3 floor entries.
- Planetary-landing implementation commit:
  `1fae0fe5652c34ab450b2da2f41cd389f00235dd`
  (`Add deterministic planetary landing regression`).
- Post-change `starflight_return_starport_native` and
  `starflight_return_starport_interpreter` continue to pass in `45.06` seconds
  each.
- Basic ship control was selected as the first bounded post-orbit path.
- The original three-field launch constructor reaches ship mode but not a
  controllable/outfitted state: Right is byte-for-byte identical to idle, and C
  enters a crash/game-over path.
- An ignored legacy save state was used only as a discovery oracle. Copying
  differing canonical game-state bytes proved the control path, then page- and
  byte-level reduction removed all but seven symbolic bytes:
  `$FF943D-$FF943F`, `$FF9573`, `$FFB84D`, and `$FFB855-$FFB856`.
- With those bytes plus the existing launch constructor, holding Right for 60
  frames deterministically changes the nearby-object count at `$FFA562` from 1
  to 0 while remaining in ship mode.
- `starflight_ship_control_native` and
  `starflight_ship_control_interpreter` cover the same constructor and semantic
  checkpoint without a save-state, SRAM, screenshot, or raw-memory payload.
- Focused validation passes:
  - `starflight_ship_control_native` in `30.76` seconds;
  - `starflight_ship_control_interpreter` in `30.56` seconds.
- Fresh forced-interpreter evidence reports zero dispatch misses,
  interior-label misses, unsafe floor exits, and Tier-3 floor entries.
- Project implementation commit:
  `bb02082610e20a2d13451376bb9de78c0a7cf532`.
- An exploratory second C action reached game over and observed interior-label
  miss `$03C66E`; it is not on the accepted basic-control path and was not
  promoted as a function seed.
- Static characterization established that `$FF943D-$FF943F` form a
  three-byte navigation-location tuple initialized together by `$009016`,
  `$FF9572` is the fuel word initialized to 200 by `$00AB9E`, and `$FFA562` is
  a 16-bit nearby-object count rebuilt by `$00BE10`.
- The ship-control regression now writes the full fuel word and checks the full
  nearby-object count rather than relying on their low bytes.
- Five neutral WRAM symbols were added for those proven roles. `$FFB84D` and
  `$FFB855-$FFB856` were then resolved: `$FFB84C` is the 16-bit navigation
  object identifier set to `$07CB` by the Starport path, while
  `$FFB855-$FFB85B` is a seven-byte ship-system condition array initialized to
  100 by `$00AB8A`.
- Sustained Up did not require any additional outfitting state. Holding it for
  60 frames changes the projected nearby-object scale at `$FF938E` from `$08`
  to `$10` while ship mode and the fuel word remain unchanged.
- `starflight_navigation_native` and
  `starflight_navigation_interpreter` cover that semantic checkpoint without a
  save-state, SRAM, screenshot, or raw-memory payload.
- Focused validation passes:
  - `starflight_navigation_native` in `31.29` seconds;
  - `starflight_navigation_interpreter` in `31.07` seconds.
- Navigation implementation commit:
  `957c4830e813611c319d0a8b7eedb45a5d6b68cf`.
- Fresh forced-interpreter navigation evidence reports zero dispatch misses,
  interior-label misses, unsafe floor exits, and Tier-3 floor entries.
- Short A and B probes remain outside the accepted navigation path. Start
  deterministically opens the Operations save/resume overlay, but that is not
  a navigation or communications action.
- Regeneration imports all 40 annotations, preserves 1015 discovered functions,
  emits all 69/69 configured entries with zero code-gate rejections, and reports
  zero unsupported code-generation diagnostics.
- A fifth fresh headless Ghidra import reproduces and saves all 40 tracked
  annotations without using the ignored local project.
- The first bounded land probe established the real controller sequence from
  orbit: C opens the crew-command menu, Down selects Navigator, A opens the
  Navigator menu, and A selects Land. The ignored legacy state reaches the
  planetary surface with that sequence.
- Resume dispatch no longer calls interior continuation `$006E06` directly.
  The generic runtime can now run a callable one-time setup before the callable
  main loop and enter a separate stable dispatcher when that loop returns.
  Starflight maps those roles to `$01B336`, `$00B3AE`, and `$006DA4`.
- Focused preservation validation passes after that dispatch split:
  - `starflight_resume_policy`;
  - `starflight_navigation_native`;
  - `starflight_navigation_interpreter`.
- Implementation provenance:
  - framework `a35c88fedacd3dabeb23cd827fdbded899d9d182`
    (`Support staged resume dispatch`), pushed to
    `origin/upstream/save-state-hardening`;
  - project `acb6f4a6eaff1f4101878bc4c1e869e7fedd4fd0`
    (`Stage Starflight resume dispatch`).
- The minimized navigation fixture does not yet survive C. The command path
  restores A7 from the game-owned non-local return slot at `$FF9460`; the
  corridor normally records `$FFFFF4` there and retains a nested ROM return
  chain ending at `$006E06`. Seeding only A7, `$FF9460`, the final return word,
  or the observed tail of that chain still reaches computed target `$000000`.
  Copying the nearby crew records does not change that result, so the remaining
  dependency initially appeared to be the exact non-local unwind context rather
  than an assigned Navigator.
- Frame-level RAM capture and the dispatch-miss return site corrected that
  diagnosis. The `$000000` target came from the dynamic JSR at `$002668`,
  which reads the ship-command callback from `$FFB8E2`; it was not a return
  popped from the non-local unwind chain.
- The Starport dispatcher writes callback `$00015F7E` at `$006DEE`. Both the
  working corridor state and the legacy orbit state retain that value, while
  the minimized constructor left it zero because staged resume enters the
  launch setup and ship loop after that dispatcher prefix.
- Adding only `$FFB8E2 = $00015F7E` to the symbolic constructor removes the
  dispatch miss. No seeded `$FF9460` value, stack tail, crew record, or
  dispatcher UI constants are required.
- The deterministic C, Down, A, A sequence now transitions from ship mode back
  to the Starport corridor. `starflight_return_starport_native` and
  `starflight_return_starport_interpreter` cover that semantic transition
  without a save-state, screenshot, or raw-memory payload.
- Focused validation passes:
  - `starflight_resume_policy`;
  - `starflight_navigation_native` in `31.30` seconds;
  - `starflight_navigation_interpreter` in `31.06` seconds;
  - `starflight_return_starport_native` in `45.07` seconds;
  - `starflight_return_starport_interpreter` in `45.06` seconds.
- Fresh return-path evidence reports zero dispatch misses, interior-label
  misses, unsafe-floor exits, and Tier-3 floor entries across 2701 frames.
- Regeneration imports all 41 annotations, emits all 69/69 configured entries
  with zero code-gate rejections, and reports zero unsupported dynamic JSR or
  JMP diagnostics.
- A sixth fresh headless Ghidra import reproduces and saves all 41 tracked
  annotations without using the ignored local project.
- Project implementation commit:
  `6a4f35c5fc2b4cec2c0d89cad594f155d6c0492d`
  (`Add deterministic Starport return regression`).

### Qualified surface-return extension

The earlier directional probes started before the landed-ship initialization
had installed its menu callback and did not model Terrain Vehicle ownership.
Static disassembly and bounded runtime probes established the missing flow:

1. bit 0 of `$FF9835` is the ownership state checked by `DISEMBARK`;
2. after surface initialization, C opens the landed-ship menu and A selects its
   initial `DISEMBARK` item;
3. successful disembark changes menu state `$FF93AC` from 1 to 2 and places
   the Terrain Vehicle at `$4A02/$3E02`, already inside the ship's proximity
   bounds;
4. C, four Down presses, and A select `EMBARK`, restoring menu state 1 and ship
   coordinates `$47FE/$3BFE`;
5. holding A for 600 frames lifts off, and a bounded stabilization wait reaches
   ship mode 2 with `ORBIT ESTABLISHED`.

`starflight_surface_return.input` performs that 5,139-frame path from reset.
Both tests pass (`85.98` seconds native, `85.69` seconds forced interpreter)
with the same final checkpoint: active crew 1, Terrain Vehicle status `$01`,
fuel `$00C6`, navigation object `$07BC`, one nearby object, scale `$18`, menu
state 0, and ship-menu renderer `$00C886`.

The four dynamic callback roots `$0081E2`, `$008206`, `$00822C`, and `$008352`
were validated against 68000 disassembly and promoted. Regeneration imports 49
annotations, emits all 82 configured entries with zero code-gate rejections,
and reports zero unsupported instructions. Fresh forced-interpreter evidence
for the accepted path reports zero dispatch misses, interior-label misses,
unsafe-floor exits, and Tier-3 entries. The prior seven-test resume, landing,
and surface preservation set also passes 7/7.

### Steps

1. Define the next bounded path after orbit:
   - **Complete:** basic ship control;
   - **Complete:** navigation;
   - **Complete:** land or return to Starport;
   - **Complete:** save and reload.
2. **Complete for basic control, navigation, landing, and return to Starport:** Traverse the path natively with evidence enabled.
3. Promote validated Tier-3 targets in small batches.
4. **Complete for basic control, navigation, landing, and return to Starport:** Compare native and interpreter state at checkpoints.
5. **Complete for basic control, navigation, landing, and return to Starport:** Add semantic regressions for each accepted mode.
6. Track remaining fallback coverage explicitly.
7. Investigate VBlank observability only if a measured timing defect depends on it.

### Acceptance criteria

- The selected path is manually and deterministically reproducible.
- Native and interpreter state agree at defined checkpoints.
- No silent dispatch miss or unsupported instruction occurs.

## Workstream 6: Package and document the milestone

**Owner:** release/integration agent
**Dependencies:** selected correctness workstreams

### Progress record

- Qualification started from project
  `0eba92012182b5c86599dfdc519b23d6650e890a` and framework
  `a35c88fedacd3dabeb23cd827fdbded899d9d182`.
- The existing Release executable is Mach-O 64-bit arm64.
- Its dynamic dependencies are Homebrew SDL2 compatibility plus the macOS
  system C++ and system libraries.
- Documentation now lists the full SRAM and accepted gameplay regression
  surface and distinguishes the accepted return-to-Starport endpoint from
  exploratory planetary landing.
- The Release target rebuilds successfully. All 12 Starflight tests pass:
  resume policy, boot, two SRAM lifecycle tests, and native/interpreter launch,
  ship-control, navigation, and return-to-Starport pairs.
- The first full Starflight run exposed a stale save/reload harness expression:
  runtime reached the staged `$01B336` setup and `$00B3AE` dispatcher, while
  the harness still expected the former direct `$006E06` continuation text.
  The assertion now checks the staged resume contract, and its focused rerun
  passes.
- All 16 framework tests pass when CTest inherits the documented Homebrew
  LLVM/lld environment. Without that environment, the nested
  `generated_input_paths` configure probe selects `/usr/bin/cc` and encounters
  the known macOS 27 `arm64e.x1` system-linker defect.
- `git diff --check` passes.
- Qualification commit
  `5fb15d362b33cfb3b0f392c941d2f7c5ed5d5c29` records the documentation and
  SRAM harness correction needed by a clean checkout.
- The first recursive-clone attempt exposed relative m68k and z80 core URLs
  that resolved against nonexistent private sibling repositories. Both pinned
  commits are available from their public `mstan` upstream repositories, so
  framework commit `c8d0f3a83bc0fde70d549777ad865f75698a68c4`
  records explicit public URLs and the project advances its submodule pointer.
- Framework commit `c8d0f3a83bc0fde70d549777ad865f75698a68c4`
  and project commit `addb274ccf757a39197b3b910b8f8c586c6961d0`
  were published to their tracked branches.
- A new recursive clone from the private project remote fetched the framework
  and all five nested submodules at their pinned revisions. Only the verified
  ROM was copied into the clone; no save, build, evidence, screenshot, or
  Ghidra artifact was supplied.
- The fresh clone configured and built a Mach-O 64-bit arm64 Release executable
  with Homebrew Clang 23.1.3 and lld.
- Fresh-clone validation passes all 16 framework tests and all 12 Starflight
  tests. The Release preset builds only `StarflightRecomp`, so the standalone
  `starflight_resume_policy_test` target was built explicitly before its
  successful CTest run; the exact commands are now documented in `README.md`.

### Steps

1. **Complete:** Verify a clean Release arm64 build from a fresh checkout.
2. **Complete in the fresh clone:** Confirm executable architecture and dynamic
   dependencies.
3. **Complete in the current worktree and fresh remote clone:** Run:
   - full framework tests;
   - Starflight boot regression;
   - launch regression;
   - SRAM lifecycle regression;
   - selected gameplay regressions.
4. **Complete:** Update documentation with:
   - supported ROM identity;
   - build and run commands;
   - controls;
   - save location and persistence;
   - accepted gameplay scope;
   - fallback status;
   - known limitations.
5. **Complete:** Record build provenance.
6. Treat a macOS `.app` bundle as a separate optional task.

### Acceptance criteria

- **Satisfied:** Another agent can reproduce the milestone without
  session-local files.
- **Satisfied:** Required tests pass from clean worktrees.
- **Satisfied:** Documentation matches measured behavior.
- **Satisfied:** No ROM, save state, extracted asset, or Ghidra database is
  distributed.

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

## Qualified milestone — Complete

The milestone is complete. A fresh recursive clone, supplied only with the
verified ROM, can:

1. configure and build a native arm64 executable;
2. pass boot, launch, SRAM, and framework tests;
3. create and load crew/ship state across process restart;
4. complete the Starport exit and reach `ORBIT ESTABLISHED`;
5. reproduce tracked Ghidra annotations and discovery inputs;
6. do all of this with clean repositories and no local save-state dependency.
