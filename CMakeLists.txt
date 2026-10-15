cmake_minimum_required(VERSION 3.16)
project(StarflightRecomp VERSION 0.1.0 LANGUAGES C CXX)

include(CTest)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(RECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/segagenesisrecomp")
set(RUNNER_ROOT "${RECOMP_ROOT}/runner")
set(STARFLIGHT_GAME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/game")

find_package(SDL2 REQUIRED CONFIG)

option(STARFLIGHT_ENABLE_TRACE "Enable runtime evidence and debug server" ON)

include("${RECOMP_ROOT}/cmake/GenesisRecompGenerated.cmake")
genesisrecomp_add_generated_sources(
    STARFLIGHT_GENERATED_SOURCES
    starflight
    "${STARFLIGHT_GAME_DIR}"
    starflight.gen)
genesisrecomp_runner_sources(
    STARFLIGHT_RUNNER_SOURCES
    TRACE ${STARFLIGHT_ENABLE_TRACE})

add_executable(StarflightRecomp
    ${STARFLIGHT_RUNNER_SOURCES}
    ${STARFLIGHT_GENERATED_SOURCES}
    "${STARFLIGHT_GAME_DIR}/starflight_spec.c")
add_dependencies(
    StarflightRecomp
    ${STARFLIGHT_GENERATED_SOURCES_TARGET})

target_include_directories(StarflightRecomp PRIVATE
    "${RUNNER_ROOT}"
    "${RUNNER_ROOT}/include"
    "${RUNNER_ROOT}/external/ymfm/src"
    "${RUNNER_ROOT}/external/superzazu"
    "${RUNNER_ROOT}/external/clowncommon"
    "${RUNNER_ROOT}/video"
    "${RECOMP_ROOT}/recompiler/src"
    "${STARFLIGHT_GAME_DIR}"
    "${STARFLIGHT_GENERATED_SOURCES_DIR}")

target_compile_definitions(StarflightRecomp PRIVATE
    INCLUDE_GENERATED_CODE=1
    ENABLE_RECOMPILED_CODE=1
    OWN_BACKEND=1
    DEFAULT_DEBUG_PORT=4378
    GENESIS_GAME_VERSION="${PROJECT_VERSION}"
    $<$<BOOL:${STARFLIGHT_ENABLE_TRACE}>:GEN_ENABLE_TRACE=1>)

target_link_libraries(StarflightRecomp PRIVATE SDL2::SDL2main SDL2::SDL2)
genesisrecomp_runner_target(StarflightRecomp)

if(BUILD_TESTING)
    add_executable(starflight_resume_policy_test
        tests/starflight_resume_policy_test.c
        "${STARFLIGHT_GAME_DIR}/starflight_spec.c")
    target_include_directories(starflight_resume_policy_test PRIVATE
        "${RUNNER_ROOT}"
        "${RUNNER_ROOT}/include")
    add_test(NAME starflight_resume_policy COMMAND starflight_resume_policy_test)

    add_test(
        NAME starflight_boot_smoke
        COMMAND StarflightRecomp
            --no-launcher
            --turbo
            --fresh-evidence
            --max-frames 1300
            --input-script "${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_boot_smoke.input"
            "${STARFLIGHT_GAME_DIR}/starflight.gen")
    set_tests_properties(starflight_boot_smoke PROPERTIES
        ENVIRONMENT "SDL_VIDEODRIVER=dummy;SDL_AUDIODRIVER=dummy"
        RESOURCE_LOCK starflight_runtime
        TIMEOUT 60)

    add_test(
        NAME starflight_sram_roundtrip
        COMMAND "${CMAKE_COMMAND}"
            "-DSTARFLIGHT_EXE=$<TARGET_FILE:StarflightRecomp>"
            "-DSTARFLIGHT_GAME=${STARFLIGHT_GAME_DIR}/starflight.gen"
            "-DSRAM_WRITE_SCRIPT=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_sram_write.input"
            "-DSRAM_READ_SCRIPT=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_sram_read.input"
            "-DSRAM_PATH=$<TARGET_FILE_DIR:StarflightRecomp>/starflight.srm"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/run_sram_roundtrip.cmake")
    set_tests_properties(starflight_sram_roundtrip PROPERTIES
        RESOURCE_LOCK starflight_runtime
        TIMEOUT 60)

    add_test(
        NAME starflight_sram_game_save
        COMMAND "${CMAKE_COMMAND}"
            "-DSTARFLIGHT_EXE=$<TARGET_FILE:StarflightRecomp>"
            "-DSTARFLIGHT_GAME=${STARFLIGHT_GAME_DIR}/starflight.gen"
            "-DSRAM_SAVE_SCRIPT=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_sram_game_save.input"
            "-DSRAM_LOAD_SCRIPT=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_sram_game_load.input"
            "-DSRAM_PATH=$<TARGET_FILE_DIR:StarflightRecomp>/starflight.srm"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/run_sram_game_save.cmake")
    set_tests_properties(starflight_sram_game_save PROPERTIES
        RESOURCE_LOCK starflight_runtime
        TIMEOUT 90)

    foreach(mode IN ITEMS native interpreter)
        add_test(
            NAME starflight_launch_${mode}
            COMMAND StarflightRecomp
                --no-launcher
                --turbo
                --fresh-evidence
                --max-frames 1900
                --input-script "${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_launch_regression.input"
                "${STARFLIGHT_GAME_DIR}/starflight.gen")
        if(mode STREQUAL "interpreter")
            set(force_interp 1)
        else()
            set(force_interp 0)
        endif()
        set_tests_properties(starflight_launch_${mode} PROPERTIES
            ENVIRONMENT "SDL_VIDEODRIVER=dummy;SDL_AUDIODRIVER=dummy;GENESIS_FORCE_INTERP=${force_interp}"
            PASS_REGULAR_EXPRESSION "Starflight resume loop returned at \\$016BAE with saved A7 \\$FFF000; continuing via setup \\$01B336 and dispatcher \\$00B3AE"
            RESOURCE_LOCK starflight_runtime
            TIMEOUT 60)
    endforeach()

    foreach(mode IN ITEMS native interpreter)
        add_test(
            NAME starflight_ship_control_${mode}
            COMMAND StarflightRecomp
                --no-launcher
                --turbo
                --fresh-evidence
                --max-frames 1900
                --input-script "${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_ship_control.input"
                "${STARFLIGHT_GAME_DIR}/starflight.gen")
        if(mode STREQUAL "interpreter")
            set(force_interp 1)
        else()
            set(force_interp 0)
        endif()
        set_tests_properties(starflight_ship_control_${mode} PROPERTIES
            ENVIRONMENT "SDL_VIDEODRIVER=dummy;SDL_AUDIODRIVER=dummy;GENESIS_FORCE_INTERP=${force_interp}"
            PASS_REGULAR_EXPRESSION "Starflight resume loop returned at \\$016BAE with saved A7 \\$FFF000; continuing via setup \\$01B336 and dispatcher \\$00B3AE"
            RESOURCE_LOCK starflight_runtime
            TIMEOUT 60)
    endforeach()

    foreach(mode IN ITEMS native interpreter)
        add_test(
            NAME starflight_navigation_${mode}
            COMMAND StarflightRecomp
                --no-launcher
                --turbo
                --fresh-evidence
                --max-frames 1900
                --input-script "${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/starflight_navigation.input"
                "${STARFLIGHT_GAME_DIR}/starflight.gen")
        if(mode STREQUAL "interpreter")
            set(force_interp 1)
        else()
            set(force_interp 0)
        endif()
        set_tests_properties(starflight_navigation_${mode} PROPERTIES
            ENVIRONMENT "SDL_VIDEODRIVER=dummy;SDL_AUDIODRIVER=dummy;GENESIS_FORCE_INTERP=${force_interp}"
            PASS_REGULAR_EXPRESSION "Starflight resume loop returned at \\$016BAE with saved A7 \\$FFF000; continuing via setup \\$01B336 and dispatcher \\$00B3AE"
            RESOURCE_LOCK starflight_runtime
            TIMEOUT 60)
    endforeach()
endif()
