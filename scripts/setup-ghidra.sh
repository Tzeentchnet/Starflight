#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rom=${1:-"$root/Starflight (USA, Europe).gen"}
project_dir="$root/ghidra/projects"
project_name=Starflight
expected=31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250
ghidra_root=$(brew --prefix ghidra)/libexec
java_home=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home

if [ ! -f "$rom" ]; then
    echo "ROM not found: $rom" >&2
    exit 1
fi

actual=$(shasum -a 256 "$rom" | awk '{print $1}')
if [ "$actual" != "$expected" ]; then
    echo "Unsupported ROM SHA-256: $actual" >&2
    echo "Expected: $expected" >&2
    exit 1
fi

if [ -e "$project_dir/$project_name.gpr" ]; then
    echo "Ghidra project already exists: $project_dir/$project_name.gpr" >&2
    exit 1
fi

cmake -E make_directory "$project_dir"
JAVA_HOME="$java_home" "$ghidra_root/support/analyzeHeadless" \
    "$project_dir" "$project_name" \
    -import "$rom" \
    -processor 68000:BE:32:default \
    -scriptPath "$root/ghidra/scripts" \
    -postScript ImportStarflightAnnotations.java \
        "$root/game/annotations.csv" "$expected" \
    -analysisTimeoutPerFile 120
