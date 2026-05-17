#!/bin/sh
#
# This script cross-compiles a Crystal program for all available platforms
# for smoke testing.
#
# Usage:
#
#    ./scripts/smoke-platforms.sh [options]
#
#    All options and arguments are forwarded to `crystal build`

set -eu

find src/lib_c/ -mindepth 1  -maxdepth 1 -type d -printf '%f\0' | xargs --verbose -0 -I{} bin/crystal build --target={} --cross-compile "$@"
