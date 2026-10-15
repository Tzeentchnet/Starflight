// Imports ROM-bound Starflight labels into the current headless Ghidra program.
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.SourceType;

public class ImportStarflightAnnotations extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 2) {
            throw new IllegalArgumentException(
                "annotations.csv expected-rom-sha256");
        }

        String actualHash = currentProgram.getExecutableSHA256();
        if (!args[1].equalsIgnoreCase(actualHash)) {
            throw new IllegalArgumentException(
                "ROM SHA-256 mismatch: " + actualHash);
        }

        MemoryBlock wram = currentProgram.getMemory().getBlock("WRAM");
        if (wram == null) {
            wram = currentProgram.getMemory().createUninitializedBlock(
                "WRAM", toAddr(0xFF0000), 0x10000, false);
            wram.setRead(true);
            wram.setWrite(true);
            wram.setExecute(false);
        }

        List<String> lines = Files.readAllLines(Path.of(args[0]));
        int imported = 0;
        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("#")) {
                continue;
            }

            String[] columns = line.split(",", -1);
            if (columns.length < 2) {
                throw new IllegalArgumentException(
                    "Invalid annotation row: " + line);
            }

            Address address = toAddr(Long.parseUnsignedLong(columns[0], 16));
            currentProgram.getSymbolTable().createLabel(
                address, columns[1], SourceType.USER_DEFINED);
            imported++;
        }

        for (long entry : new long[] { 0x200, 0x326, 0x33A }) {
            Address address = toAddr(entry);
            disassemble(address);
            if (getFunctionAt(address) == null) {
                createFunction(address, null);
            }
        }

        println("Imported " + imported + " Starflight annotations");
    }
}
