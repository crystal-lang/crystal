# Overview of Workflows

- no symbol: triggers on every commit.
- 🕑: triggers on a nightly schedule.
- 📂: triggers on every commit when it contains changes to a subtree
- 🏷️: triggers on a tag

## Test Workflows

### Standard specs (`std_spec`)

- `bsd.yml#freebsd`:
  - `x86_64-freebsd`
- `interpreter.yml#test-interpreter-std_spec`:
  - `x86_64-linux-gnu`
- `linux.yml#test-std`: each in 5 runtime configurations
  - `x86_64-linux-gnu`
  - `aarch64-linux-gnu`
- `macos.yml#test-std`:
  - `x86_64-darwin`
  - `aarch64-darwin`
- `wasm32.yml#wasm32-test`:
  - `wasm32-wasi` (on `x86_64-linux-gnu`)

### "Full test" (`scripts/ci-build.sh`)

> - `std_spec`
> - `make crystal`
> - `primitives_spec`, `std_spec`, `compiler_spec`, `docs`
> - `samples`, `samples --debug`

- `linux.yml#test`:
  - `x86_64-linux-gnu`
  - `x86_64-linux-musl`
  - `aarch64-linux-gnu`
  - `aarch64-linux-musl`
- `macos.yml#darwin-test`:
  - `x86_64-darwin`
  - `aarch64-darwin`
- 🕑 `forward-compatibility.yml#x86_64-gnu-test-forward_compatibility`: each for six previous releases
  - `x86_64-linux-gnu`

### MinGW tests

> - `make crystal`, `make shards`
> - `std_spec`
> - `compiler_spec`, `interpreter_spec`, `primitive_specs`, `cli_spec`

- `mingw-w64.yml#x86_64-mingw-w64`:
  - `x86_64-mingw-w64`
- `mingw-w64.yml#aarch64-mingw-w64`:
  - `aarch64-mingw-w64`

### MSVC test

> - `make crystal`, `make shards` (full release package)
> - `std_spec`, `compiler_spec`, `interpreter_spec`, `primitives_spec`, `cli_spec`, `samples`
> - `std_spec`
> - `i std_spec`, `i primitives_spec`

- `win.yml#x86_64-msvc`
  - `x86_64-windows-msvc`
- `win.yml#aarch64-msvc`
  - `aarch64-windows-msvc`

### Interpreter specs (`interpreter_spec`)

`interpreter.yml#build-interpreter`

- `interpreter.yml#test-interpreter_spec`:
  - `x86_64-linux-gnu`
- `macos.yml#darwin-test`:
  - `x86_64-darwin`
  - `aarch64-darwin`

### Interpreter primitives spec (`primitives_specs`)

- `interpreter.yml#test-interpreter-primitives_spec`:
  - `x86_64-linux-gnu`

### Smoke tests (`make crystal` + `simple_smoke_test`)

- `smoke.yml#smoke-test`
  - all supported and untested targets

### LLVM Compatibility (`compiler_spec` + `make crystal` + `std_spec`)

Triggers schedule and on all commits with LLVM or compiler source code changes.

- 🕑/📂 `llvm.yml#llvm_test`: each for all supported LLVM releases
  - `x86_64-linux-gnu`

### OpenSSL Compatibility (`bin/crystal spec --order=random spec/std/openssl`)

Triggers schedule and on all commits with OpenSSL source code changes.

- 🕑/📂 `openssl.yml#libssl_test`: each for all supported previous OpenSSL and LibreSSL releases
  - `x86_64-linux-musl`

### Regex Engine Compatibility (`bin/crystal spec spec/std/regex*`)

Triggers schedule and on all commits with Regex source code changes.

- 🕑/📂 `regex-engine.yml#pcre`, `regex-engine.yml#pcre2`
  - `x86_64-linux-musl`

### LibXML compatibility (`bin/crystal spec spec/std/xml`)

Triggers schedule and on changes to XML source code.

- 🕑/📂 `xml.yml#libssl_test`: each with 4 different libxml2 versions
  - `x86_64-linux-alpine`

## Maintenance Workflows

### Lint hooks

- `prek run`: `lint.yml#prek`
- `make crystal` + `make format`: `linux.yml#check_format`

### Devenv housekeeping (`devenv update`)

- 🕑 `update-devenv.yml#update-devenv`

## Build Workflows

### Linux and macOS Builds

Triggers nightly, on tag, and `ci/*` branch

- 🕑🏷️ `../.circleci/config.yml`
  - `x86_64-linux`, `aarch64-lnux`: static binary tarball, docker images, snap, OBS nightly package
  - `x86_64-darwin` / `aarch64-darwin`: universal build tarball
  - docs

### Windows Installer

Triggers on tag or `ci/*` branch

- 🏷️ `win.yml` -> `win-steps.yml#build-installer`
  - `arch_64-windows-msvc`
  - `x86_64-windows-mscv`

### Master Docs

- (master) `make crystal docs`
  - `docs.yml#deploy_api_docs`: `ubuntu-latest`
