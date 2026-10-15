#include "game_spec.h"
#include "genesis_runtime.h"

#include <assert.h>
#include <stdint.h>

M68KState g_cpu;
uint8_t g_rom[0x400000];
uint8_t g_ram[0x010000];

void recomp_call_addr(uint32_t address)
{
    (void)address;
}

static void write_wram_u16(uint16_t address, uint16_t value)
{
    g_ram[address] = (uint8_t)(value >> 8);
    g_ram[(uint16_t)(address + 1u)] = (uint8_t)value;
}

static uint32_t resolve(uint8_t mode)
{
    uint32_t pc = 0;
    assert(game_spec_resolve_save_resume_pc(&g_game_spec, true, mode, &pc));
    return pc;
}

int main(void)
{
    write_wram_u16(0x82ECu, 0u);
    write_wram_u16(0x95B8u, 0u);
    assert(resolve(1u) == 0x0130B0u);

    write_wram_u16(0x82ECu, 1u);
    write_wram_u16(0x95B8u, 0x005Au);
    assert(resolve(1u) == 0x016BAEu);

    assert(resolve(0u) == 0x006DA4u);
    assert(resolve(2u) == 0x006DA4u);
    assert(g_game_spec.resume_dispatch_setup_pc == 0x01B336u);
    assert(g_game_spec.dispatch_main_loop_pc == 0x00B3AEu);
    assert(g_game_spec.redispatch_main_loop_pc == 0x006DA4u);

    uint32_t pc = 0;
    assert(!game_spec_resolve_save_resume_pc(
        &g_game_spec, true, 0xFFu, &pc));
    return 0;
}
