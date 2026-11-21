#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rom=${1:-"$root/Starflight (USA, Europe).gen"}

exec "$root/build/macos-arm64/Starflight.app/Contents/MacOS/Starflight" "$rom"
