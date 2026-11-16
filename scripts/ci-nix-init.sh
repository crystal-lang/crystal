#!/bin/sh
#
# Initializes the Nix environment for nix-shell

set -eu

# Install a recent bash version for nix-shell because macos ships an incompatible ancient version (https://github.com/crystal-lang/crystal/pull/10480)
if [ "$(uname)" = "Darwin" ]; then
  brew install bash
fi

nix-shell --run true
