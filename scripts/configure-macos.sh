#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rom=${1:-"$root/Starflight (USA, Europe).gen"}
expected=31b9d25fcde71c9707a408d58ca229a3b87c1e4fd1300cc407f2ac1d13f15250

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

ln -sfn "$rom" "$root/game/starflight.gen"
cmake --preset macos-arm64-release -S "$root"
