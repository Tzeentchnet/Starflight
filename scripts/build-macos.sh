#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cmake --build "$root/build/macos-arm64" --target StarflightRecomp
