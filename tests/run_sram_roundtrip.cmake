foreach(required IN ITEMS STARFLIGHT_EXE STARFLIGHT_GAME SRAM_WRITE_SCRIPT
        SRAM_READ_SCRIPT SRAM_PATH)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

file(REMOVE "${SRAM_PATH}")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        SDL_VIDEODRIVER=dummy
        SDL_AUDIODRIVER=dummy
        "${STARFLIGHT_EXE}"
        --no-launcher
        --turbo
        --max-frames 1265
        --input-script "${SRAM_WRITE_SCRIPT}"
        "${STARFLIGHT_GAME}"
    RESULT_VARIABLE write_result
    OUTPUT_VARIABLE write_stdout
    ERROR_VARIABLE write_stderr)

if(NOT write_result EQUAL 0)
    file(REMOVE "${SRAM_PATH}")
    message(FATAL_ERROR
        "SRAM writer failed (${write_result})\n${write_stdout}\n${write_stderr}")
endif()

if(NOT EXISTS "${SRAM_PATH}")
    message(FATAL_ERROR "SRAM writer did not create ${SRAM_PATH}")
endif()

file(SIZE "${SRAM_PATH}" sram_size)
if(NOT sram_size EQUAL 16384)
    file(REMOVE "${SRAM_PATH}")
    message(FATAL_ERROR "SRAM file is ${sram_size} bytes; expected 16384")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        SDL_VIDEODRIVER=dummy
        SDL_AUDIODRIVER=dummy
        "${STARFLIGHT_EXE}"
        --no-launcher
        --turbo
        --max-frames 5
        --input-script "${SRAM_READ_SCRIPT}"
        "${STARFLIGHT_GAME}"
    RESULT_VARIABLE read_result
    OUTPUT_VARIABLE read_stdout
    ERROR_VARIABLE read_stderr)

file(REMOVE "${SRAM_PATH}")

if(NOT read_result EQUAL 0)
    message(FATAL_ERROR
        "SRAM reader failed (${read_result})\n${read_stdout}\n${read_stderr}")
endif()

if(NOT write_stderr MATCHES "\\[SRAM\\] flushed 16384 bytes")
    message(FATAL_ERROR "writer did not report a 16 KiB flush\n${write_stderr}")
endif()
if(NOT read_stderr MATCHES "\\[SRAM\\] loaded 16384/16384 bytes")
    message(FATAL_ERROR "reader did not report a complete reload\n${read_stderr}")
endif()

message(STATUS "Starflight SRAM 16 KiB flush/reload round trip passed")
