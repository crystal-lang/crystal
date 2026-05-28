#!/usr/bin/env sh
#
# This helper updates all references to the previous Crystal release as bootstrap version with a new release.
#
# Usage:
#
#    scripts/release-update.sh 1.3.0
#
# See Crystal release checklist: https://github.com/crystal-lang/distribution-scripts/blob/master/processes/crystal-release.md#post-release
set -eu

CRYSTAL_VERSION=$1

##
## 1. Update development branch to track next version
##    and remove release artifacts (`src/SOURCE_DATE_EPOCH`)
##
## This should only be needed after minor releases, but it's idempotent for
## patch releases, so we can run it always.
##

# Write dev version for next minor release into src/VERSION
minor_branch="${CRYSTAL_VERSION%.*}"
next_minor="$((${minor_branch#*.} + 1))"
echo "${CRYSTAL_VERSION%%.*}.${next_minor}.0-dev" > src/VERSION

# Update shard.yml
sed -i -E "s/version: .*/version: $(cat src/VERSION)/" shard.yml

# Remove SOURCE_DATE_EPOCH (only used in source tree of a release)
rm -f src/SOURCE_DATE_EPOCH

##
## 2. Add previous release to forward compatibility tests (if new minor branch)
##

previous_release=$(grep -o -P '(?<=\$\{CRYSTAL_BOOTSTRAP_VERSION:=).*(?=\})' bin/ci)
if [ "${minor_branch}" != "${previous_release%.*}" ]; then
  sed -i -E "/crystal_bootstrap_version:/ s/(, ${previous_release%.*}\.[0-9]*)?\]\$/, $previous_release]/" .github/workflows/forward-compatibility.yml
fi

##
## 3. Update CI and build scripts to use latest release as bootstrap version
##

# Edit PREVIOUS_CRYSTAL_BASE_URL in .circleci/config.yml
sed -i -E "s|[0-9.]+/crystal-[0-9.]+-[0-9]|$CRYSTAL_VERSION/crystal-$CRYSTAL_VERSION-1|g" .circleci/config.yml

# Edit DOCKER_TEST_PREFIX in bin/ci
# shellcheck disable=SC2016
sed -i -E 's|\$\{CRYSTAL_BOOTSTRAP_VERSION:=.*\}|\${CRYSTAL_BOOTSTRAP_VERSION:='"$CRYSTAL_VERSION"'}|' bin/ci

sed -i -E "s|crystallang/crystal:[0-9.]+|crystallang/crystal:$CRYSTAL_VERSION|g" .github/workflows/*.yml

# Edit .github/workflows/*.yml to update version for install-crystal action
sed -i -E "s|crystal: \"[0-9.]+\"|crystal: \"$CRYSTAL_VERSION\"|g" .github/workflows/*.yml

# Edit shell.nix latestCrystalBinary using nix-prefetch-url --unpack <url>
update_shell_nix_release() {
  target="$1"
  release_url="https://github.com/crystal-lang/crystal/releases/download/$CRYSTAL_VERSION/crystal-$CRYSTAL_VERSION-1-$target.tar.gz"
  release_sha=$(nix-prefetch-url --unpack "$release_url")

  sed -i -E "s|https://github.com/crystal-lang/crystal/releases/download/[0-9.]+/crystal-[0-9.]+-[0-9]-$target.tar.gz|$release_url|" shell.nix
  sed -i -E "/${target}\.tar\.gz/ {n;s|sha256:[^\"]+|sha256:$release_sha|}" shell.nix
}

update_shell_nix_release "darwin-universal"
update_shell_nix_release "linux-x86_64"
update_shell_nix_release "linux-aarch64"
