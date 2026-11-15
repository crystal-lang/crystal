#!/bin/sh
#
# Runs a full CI build suite

set -eu

: : "${GITHUB_ACTIONS:=false}"

run() {
  if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "::group::${*}"
  fi

  eval "${*}"

  if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "::endgroup::"
  fi
}

# 0. Print Regex configuration
run bin/crystal run scripts/print_regex_config.cr

# 1. Run standard specs on base compiler
run make std_spec clean threads=1 junit_output=.junit/std_spec.xml

# 2.a Build compiler
run make crystal threads=1 junit_output=.junit/spec.xml

# 2.b run primitives, std, and compiler specs.
run make primitives_spec threads=1 junit_output=.junit/spec.xml
run make std_spec threads=1 junit_output=.junit/spec.xml
run make compiler_spec threads=1 junit_output=.junit/spec.xml

# 2.c Build docs.
run make docs threads=1 junit_output=.junit/spec.xml \
  DOCS_OPTIONS=\"--json-config-url=/api/versions.json --canonical-base-url=https://crystal-lang.org/api/latest/\"

# 3.a Build samples
run make samples

# 3.b Build samples in debug mode
run CRYSTAL_OPTS=--debug make samples
