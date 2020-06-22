#!/bin/sh

# This file can be executed from the root of the working copy
#
# $ ./spec/debug/test.sh
#
# It will use the ./spec/debug/driver.cr program to execute
# the files explicitly listed at the end of this file.
#
# Those files have magic comments to build a script for an lldb session
# and a FileCheck file with assertions over that session.
#
# In ./tmp/debug you can find a dump of the session and the assertion file.
#
# The magic comments interpreted by the driver are:
#
#   * # break
#   * # lldb-command:
#   * # lldb-check:
#

set -euo pipefail

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_ROOT="$(dirname "$SCRIPT_PATH")"

BUILD_DIR=$SCRIPT_ROOT/../../.build
crystal=$SCRIPT_ROOT/../../bin/crystal
driver=$BUILD_DIR/debug_driver
mkdir -p $BUILD_DIR
$crystal build $SCRIPT_ROOT/driver.cr -o $driver

$driver $SCRIPT_ROOT/top_level.cr
$driver $SCRIPT_ROOT/strings.cr
$driver $SCRIPT_ROOT/blocks.cr
