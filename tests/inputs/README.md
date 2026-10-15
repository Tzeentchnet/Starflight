# Input scripts

`starflight_boot_smoke.input` is the only automated regression in this
directory. It starts from reset and is registered with CTest.

The other scripts are manual reverse-engineering probes. Most require ignored
local `native_save_*.bin` files and may write ignored screenshots, save states,
or runtime evidence. They are not clean-checkout tests and must not be used as
milestone acceptance evidence until their local-state dependency is replaced.

`starflight_launch_persist.input` intentionally omits `EXIT` so a persistence
probe can close through the normal runtime shutdown path.
