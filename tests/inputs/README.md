# Input scripts

`starflight_boot_smoke.input` and `starflight_launch_regression.input` are
automated regressions registered with CTest. Both start from reset. The launch
regression constructs the minimum observed station-exit state with symbolic
WRAM writes, seeds a non-default saved A7, restarts at the generated `$016BAE`
boundary, and verifies the transition to ship mode in native and
forced-interpreter execution.

`starflight_ship_control.input` extends the launch constructor with symbolic
navigation, fuel, and ship-condition state. It reaches a controllable orbit
state, holds Right for 60 frames, and verifies that the 16-bit nearby-object
count at `$FFA562` deterministically changes from one to zero in native and
forced-interpreter execution. The recipe was reduced from a legacy local-state
comparison; the test itself has no save-state, SRAM, screenshot, or raw-memory
payload dependency.

`starflight_navigation.input` reuses that symbolic constructor, holds Up for 60
frames, and verifies that the projected nearby-object scale at `$FF938E`
changes from `$08` to `$10` while ship mode and the fuel word remain unchanged.
It covers the same path in native and forced-interpreter execution without
adding outfitting state or local artifacts.

`starflight_sram_write.input` and `starflight_sram_read.input` are paired by the
`starflight_sram_roundtrip` CTest. The first process writes byte and word
sentinels at both ends of the 16 KiB SRAM window and exits through normal
`--max-frames` cleanup. The second process verifies exact reload before guest
startup can mutate SRAM. This is a host persistence regression, not evidence of
an in-game crew/ship save.

`starflight_sram_game_save.input` enters the validated symbolic Starport
corridor, assigns non-empty `TEST` ship and `CREW` crew names, opens Operations
with Start, and selects `SAVE AS GAME 1` with A.
`starflight_sram_game_load.input` runs in a second process, loads GAME 1 from
the title menu, verifies both symbolic fields, and launches to orbit. Their
CTest uses no local save state or scripted `EXIT`.

The other scripts are manual reverse-engineering probes. Most require ignored
local `native_save_*.bin` files and may write ignored screenshots, save states,
or runtime evidence. They are not clean-checkout tests and must not be used as
milestone acceptance evidence until their local-state dependency is replaced.

`starflight_launch_persist.input` intentionally omits `EXIT` so a persistence
probe can close through the normal runtime shutdown path.
