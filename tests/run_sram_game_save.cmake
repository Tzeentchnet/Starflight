foreach(required IN ITEMS STARFLIGHT_EXE STARFLIGHT_GAME SRAM_SAVE_SCRIPT
        SRAM_LOAD_SCRIPT SRAM_PATH)
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
        --max-frames 1400
        --input-script "${SRAM_SAVE_SCRIPT}"
        "${STARFLIGHT_GAME}"
    RESULT_VARIABLE save_result
    OUTPUT_VARIABLE save_stdout
    ERROR_VARIABLE save_stderr)

if(EXISTS "${SRAM_PATH}")
    file(SIZE "${SRAM_PATH}" sram_size)
else()
    set(sram_size 0)
endif()

if(NOT save_result EQUAL 0)
    file(REMOVE "${SRAM_PATH}")
    message(FATAL_ERROR
        "in-game SRAM save failed (${save_result})\n${save_stdout}\n${save_stderr}")
endif()
if(NOT sram_size EQUAL 16384)
    file(REMOVE "${SRAM_PATH}")
    message(FATAL_ERROR "in-game save produced ${sram_size} bytes; expected 16384")
endif()
if(NOT save_stderr MATCHES "\\[SRAM\\] flushed 16384 bytes")
    file(REMOVE "${SRAM_PATH}")
    message(FATAL_ERROR
        "in-game save did not report a 16 KiB flush\n${save_stderr}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        SDL_VIDEODRIVER=dummy
        SDL_AUDIODRIVER=dummy
        "${STARFLIGHT_EXE}"
        --no-launcher
        --turbo
        --fresh-evidence
        --max-frames 2100
        --input-script "${SRAM_LOAD_SCRIPT}"
        "${STARFLIGHT_GAME}"
    RESULT_VARIABLE load_result
    OUTPUT_VARIABLE load_stdout
    ERROR_VARIABLE load_stderr)

file(REMOVE "${SRAM_PATH}")

if(NOT load_result EQUAL 0)
    message(FATAL_ERROR
        "saved-game reload/launch failed (${load_result})\n${load_stdout}\n${load_stderr}")
endif()
if(NOT load_stderr MATCHES "\\[SRAM\\] loaded 16384/16384 bytes")
    message(FATAL_ERROR "second process did not load 16 KiB SRAM\n${load_stderr}")
endif()
if(NOT load_stderr MATCHES
        "Starflight resume loop returned at .*016BAE with saved A7 .*FFF000; continuing at dispatcher .*006E06")
    message(FATAL_ERROR "reloaded game did not complete the launch resume\n${load_stderr}")
endif()
if(load_stderr MATCHES "interior-label miss")
    message(FATAL_ERROR "reloaded game reported an interior-label miss\n${load_stderr}")
endif()

message(STATUS
    "Starflight symbolic crew/ship state survived Save Game, process restart, reload, and launch")
