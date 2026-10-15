#include "game_spec.h"
#include "genesis_runtime.h"

#include <stddef.h>
#include <stdint.h>

static void starflight_call_entry_point(void)
{
    recomp_call_addr(0x000200u);
}

static void starflight_call_vblank(void)
{
    recomp_call_addr(0x000326u);
}

static void starflight_call_hblank(void)
{
    recomp_call_addr(0x00033Au);
}

static uint16_t starflight_wram_u16(uint16_t address)
{
    return (uint16_t)(((uint16_t)g_ram[address] << 8)
        | g_ram[(uint16_t)(address + 1u)]);
}

static uint32_t starflight_save_resume_pc(uint8_t mode)
{
    if (mode == 1u) {
        if (starflight_wram_u16(0x82ECu) == 1u
            && starflight_wram_u16(0x95B8u) != 0u)
            return 0x016BAEu;
        return 0x0130B0u;
    }
    return 0x006DA4u;
}

const GameSpec g_game_spec = {
    .display_name = "Starflight",
    .short_name = "Starflight",
    .expected_rom_crc32 = 0xD550C928u,
    .expected_rom_size = 0x100000u,
    .tier3_floor_default = 1,

    /*
     * The header predates the standard "RA" declaration. The cartridge's
     * startup RAM test probes 0x2000 words at $200000, establishing a 16 KiB
     * always-visible save window beyond the 1 MiB ROM.
     */
    .sram_start = 0x200000u,
    .sram_end = 0x203FFFu,

    .call_entry_point = starflight_call_entry_point,
    .call_vblank = starflight_call_vblank,
    .call_hblank = starflight_call_hblank,

    .resume_main_loop_pc = 0x0130B0u,
    .save_resume_pc = starflight_save_resume_pc,
    .dispatch_main_loop_pc = 0x006E06u,
    .call_periodic = NULL,

    .on_post_reset = NULL,
    .on_state_loaded = NULL,
    .on_frame_pre = NULL,
    .on_frame_post = NULL,
    .on_hblank = NULL,

    .handle_arg = NULL,
    .arg_usage = NULL,
    .dispatch_override = NULL,
    .instruction_hook = NULL,

    .fill_frame_record = NULL,
    .frame_record_version = 0u,
    .commands = NULL,
    .command_count = 0u,
};
