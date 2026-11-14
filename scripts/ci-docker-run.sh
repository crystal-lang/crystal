#!/bin/sh
#
# Runs a command inside a crystallang/crystal Docker image.
#
# Usage: scripts/ci-docker-run.sh [IMAGE_SUFFIX] COMMAND

set -eu

: "${CRYSTAL_BOOTSTRAP_VERSION:=1.22.2}"

if [ "$#" -ge 2 ]; then
  image_suffix="$1"
  shift
else
  image_suffix=build
fi

# NOTE: disabling seccomp because the default profile disables io_uring syscalls
docker run \
  --rm -t \
  -u "$(id -u)" \
  -v "$PWD":/mnt \
  -v /etc/passwd:/etc/passwd \
  -v /etc/group:/etc/group \
  -w /mnt \
  -e CRYSTAL_CACHE_DIR="/tmp/crystal" \
  -e SPEC_SPLIT_DOTS \
  -e USE_PCRE1 \
  -e TZ="America/New_York" \
  -e GITHUB_ACTIONS \
  --security-opt seccomp=unconfined \
  "crystallang/crystal:${CRYSTAL_BOOTSTRAP_VERSION}-$image_suffix" \
  /bin/sh -c "$1"
