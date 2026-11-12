# Starflight Surface Return Handoff

## Objective

The deterministic planetary-surface return is now implemented and qualified.
The reset-backed constructor disembarks and re-embarks the Terrain Vehicle,
leaves game mode 4 by lifting off, and reaches the same stable orbit checkpoint
in native and forced-interpreter execution.

## Repository state

- Project base revision:
  `ad010dac7337e6f2151ee34847b27c07a65876e3`
- Framework revision:
  `c8d0f3a83bc0fde70d549777ad865f75698a68c4`
- The project changes described below are uncommitted.
- The framework was not modified.
- `last_error.log` is an unrelated untracked local artifact. Do not include it
  in a commit without separately classifying it.

Current project changes:

- `CMakeLists.txt`
- `README.md`
- `game/annotations.csv`
- `ghidra/annotations/provenance.json`
- `plan.md`
- `tests/inputs/README.md`
- `tests/inputs/starflight_surface_second_action.input` (new)
- `tests/inputs/starflight_surface_return.input` (new)
- `HANDOFF.md` (this file)

## Qualified baseline

The accepted first milestone still ends with the deterministic return from ship
mode to Starport. The qualified post-milestone extensions now cover:

1. deterministic planetary landing;
2. sustained Up travel on a viable surface;
3. a bounded Left directional response on the surface;
4. a deterministic Terrain Vehicle disembark/embark and lift-off to orbit.

All gameplay regressions start from reset and construct symbolic WRAM state.
They do not require local save states, SRAM images, screenshots, raw memory
payloads, or local Ghidra projects.

### Surface constructor

`tests/inputs/starflight_surface_exploration.input` and
`tests/inputs/starflight_surface_second_action.input` contain the current
minimal surface constructor. The surface action constructor adds:

- `$FF97D3 = 1`: `ActiveCrewCount`

The return constructor adds one further explained field:

- `$FF9835 = 1`: bit 0 of `TerrainVehicleStatusFlags`, the ownership state
  checked by `DISEMBARK` and set by the outfitting path when supplying a
  missing vehicle.

The surface is reached in game mode 4 with navigation object `$07BC`.

### Qualified surface checkpoints

Sustained Up for 60 frames:

- preserves game mode 4;
- preserves `ActiveCrewCount = 1`;
- changes fuel at `$FF9572` from `$00C8` to `$00C7`.

Sustained Left for 60 frames:

- preserves game mode 4;
- preserves `ActiveCrewCount = 1`;
- preserves fuel at `$FF9572 = $00C8`;
- changes `$FF85BC` from `$6254` to `$7254`;
- changes `$FF85F4` from `$6264` to `$7264`.

`$FF85BC/$FF85F4` are tracked neutrally as paired directional sprite
tile-attribute words. Static analysis shows `$00BD1A` combines heading-derived
flip flags from `$00BD0A` with patterns `$0254/$0264`, and `$003218` emits the
resulting words at SAT+4. The observed `$1000` toggle proves a directional
render-state response, not displacement.

## Last validation

Translation generation:

```sh
cmake --build build/macos-arm64 \
  --target genesisrecomp_generate_starflight
```

Result:

- 49 annotations imported;
- 82/82 configured entries emitted;
- zero code-gate rejections;
- zero unsupported code-generation diagnostics.

Surface-return pair:

```sh
ctest --test-dir build/macos-arm64 --output-on-failure \
  -R '^starflight_surface_return_(native|interpreter)$'
```

Result:

- native passed in 85.98 seconds;
- forced interpreter passed in 85.69 seconds.

Focused preservation suite:

```sh
ctest --test-dir build/macos-arm64 --output-on-failure \
  -R '^(starflight_resume_policy|starflight_(planetary_landing|surface_exploration|surface_second_action)_(native|interpreter))$'
```

Result:

- 7/7 tests passed in 283.58 seconds.

Fresh forced-interpreter evidence for the 5,139-frame surface-return path
reported:

- zero dispatch misses;
- zero interior-label misses;
- zero unsafe-floor exits;
- zero Tier-3 floor entries.

The runtime evidence is ignored and local under `build/macos-arm64/`.
`git diff --check` passed after the final documentation correction.

## Completed surface-return extension

### Root cause

The earlier probes pressed C before surface initialization had installed the
landed-ship callback and treated the landed ship as if it were already the
Terrain Vehicle. The normal path is:

1. wait for landed-ship menu state 1;
2. select `DISEMBARK`;
3. use Terrain Vehicle menu state 2;
4. select `EMBARK`;
5. hold A to lift off.

`DISEMBARK` also checks bit 0 at `$FF9835`. When clear, the game displays
`YOU HAVE LOST YOUR TERRAIN VEHICLE.` Static outfitting code at `$018594` sets
the same bit when creating a missing vehicle, so `$FF9835 = 1` is an explained
ownership precondition rather than a coordinate or menu shortcut.

### Deterministic sequence

`tests/inputs/starflight_surface_return.input` starts from reset and reuses the
qualified landing constructor, adding only `$FF9835 = 1`.

After landing:

1. wait 600 frames for surface initialization;
2. press C, then A to select the initial `DISEMBARK` item;
3. verify mode 4, menu state 2, and Terrain Vehicle coordinates
   `$4A02/$3E02`;
4. press C, Down four times, and A to select `EMBARK`;
5. verify mode 4, menu state 1, and ship coordinates `$47FE/$3BFE`;
6. hold A for 600 frames and wait 1,200 frames for stable orbit.

The final checkpoint is:

- game mode `$FFC2A9 = 2`;
- `ActiveCrewCount` `$FF97D3 = 1`;
- `TerrainVehicleStatusFlags` `$FF9835 = 1`;
- fuel `$FF9572 = $00C6`;
- navigation object `$FFB84C = $07BC`;
- nearby-object count `$FFA562 = 1`;
- nearby-object scale `$FF938E = $18`;
- menu state `$FF93AC = 0`;
- menu renderer `$FF93B2 = $0000C886`.

### Native promotion

The dynamic callback roots were independently validated against 68000
disassembly and promoted in `game/starflight_gameplay_floor.toml`:

- `$0081E2`: landed-ship menu renderer;
- `$008206`: Terrain Vehicle menu renderer;
- `$00822C`: landed-ship menu action;
- `$008352`: Terrain Vehicle menu action.

Regeneration emits all 82 configured entries, with zero code-gate rejections
and zero unsupported diagnostics. The accepted 5,139-frame forced-interpreter
run reports zero dispatch misses, interior-label misses, unsafe-floor exits,
and Tier-3 entries.

### Acceptance status

All surface-return acceptance criteria are satisfied:

- one bounded input sequence leaves mode 4 and reaches stable mode 2;
- native and forced-interpreter runs pass with the same assertions;
- the script starts from reset and has no local-state dependency;
- the sole additional constructor byte is explained and annotated;
- generated coverage is complete for the accepted path;
- the prior resume, landing, and surface preservation set passes 7/7;
- discovery, annotations, provenance, tests, and documentation agree.
