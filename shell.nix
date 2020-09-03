# This nix-shell script can be used to get a complette development environment
# for the Crystal compiler.
#
# You can choose which llvm version use and, on Linux, choose to use musl.
#
# $ nix-shell --pure
# $ nix-shell --pure --arg llvm 10
# $ nix-shell --pure --arg llvm 10 --arg musl true
# $ nix-shell --pure --arg llvm 9
# ...
# $ nix-shell --pure --arg llvm 6
#
# If needed, you can use https://app.cachix.org/cache/crystal-ci to avoid building
# packages that are not available in Nix directly. This is only useful for musl so far.
#
# $ nix-env -iA cachix -f https://cachix.org/api/v1/install
# $ cachix use crystal-ci
# $ nix-shell --pure --arg musl true
#
# Known issue: musl does not work yet.
#   .../lib/libgc.a(pthread_support.o): in function `GC_thr_init':
#   pthread_support.c:(.text+0x1137): undefined reference to `gnu_get_libc_version'
#   .../lib/libgc.a(mach_dep.o): in function `GC_with_callee_saves_pushed':
#   mach_dep.c:(.text+0x35): undefined reference to `getcontext'
#   .../lib/libgc.a(pthread_start.o): in function `GC_inner_start_routine':
#   pthread_start.c:(.text+0x44): undefined reference to `__pthread_register_cancel'
#   .../bin/ld: pthread_start.c:(.text+0x6b): undefined reference to `__pthread_unregister_cancel'

{llvm ? 10, musl ? false}:

let
  nixpkgs = import (builtins.fetchTarball {
    name = "nixpkgs-20.03";
    url = "https://github.com/NixOS/nixpkgs/archive/2d580cd2793a7b5f4b8b6b88fb2ccec700ee1ae6.tar.gz";
    sha256 = "1nbanzrir1y0yi2mv70h60sars9scwmm0hsxnify2ldpczir9n37";
  }) {};

  pkgs = if musl then nixpkgs.pkgsMusl else nixpkgs;

  genericBinary = { url, sha256 }:
    pkgs.stdenv.mkDerivation rec {
      name = "crystal-binary";
      src = builtins.fetchurl { inherit url sha256; };

      # Extract only the compiler binary and the embedded GC
      buildCommand = ''
        mkdir -p $out/bin $out/lib $out/tmp
        tar --strip-components=1 -C $out/tmp -xf ${src}

        # Darwin packages use embedded/bin/crystal and embedded/lib/libgc.a
        [ -f "$out/tmp/embedded/lib/libgc.a" ] && mv $out/tmp/embedded/lib/libgc.a $out/lib/
        [ -f "$out/tmp/embedded/bin/crystal" ] && mv $out/tmp/embedded/bin/crystal $out/bin/

        # Linux packages use lib/crystal/bin/crystal and lib/crystal/lib/libgc.a
        [ -f "$out/tmp/lib/crystal/lib/libgc.a" ] && mv $out/tmp/lib/crystal/lib/libgc.a $out/lib/
        [ -f "$out/tmp/lib/crystal/bin/crystal" ] && mv $out/tmp/lib/crystal/bin/crystal $out/bin/

        rm -rf $out/tmp
      '';
    };

  # Hashes obtained using `nix-prefetch-url --unpack <url>`
  latestCrystalBinary = genericBinary ({
    x86_64-darwin = {
      url = "https://github.com/crystal-lang/crystal/releases/download/0.35.1/crystal-0.35.1-1-darwin-x86_64.tar.gz";
      sha256 = "sha256:1dhs18riq8lyz82948f44ya1k6pp4fy7j9wkxzqsj3wha03gfxbx";
    };

    x86_64-linux = {
      url = "https://github.com/crystal-lang/crystal/releases/download/0.35.1/crystal-0.35.1-1-linux-x86_64.tar.gz";
      sha256 = "sha256:1ygp4gf0cl8cpa8sw974lsdrngldgkyym6ha3cq0fadkfdhd6gvc";
    };

    i686-linux = {
      url = "https://github.com/crystal-lang/crystal/releases/download/0.35.1/crystal-0.35.1-1-linux-i686.tar.gz";
      sha256 = "sha256:0nfgxjndfslyacicjy4303pvvqfg74v5fnpr4b10ss9rqakmlbgd";
    };
  }.${pkgs.stdenv.system});

  pkgconfig = pkgs.pkgconfig;

  llvm_suite = ({
    llvm_10 = {
      llvm = pkgs.llvm_10;
      extra = [ pkgs.lld_10 pkgs.lldb_10 ];
    };
    llvm_9 = {
      llvm = pkgs.llvm_9;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
    llvm_8 = {
      llvm = pkgs.llvm_8;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
    llvm_7 = {
      llvm = pkgs.llvm;
      extra = [ pkgs.lldb ];
    };
    llvm_6 = {
      llvm = pkgs.llvm_6;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
  }."llvm_${toString llvm}");

  stdLibDeps = with pkgs; [
      gmp libevent libiconv libxml2 libyaml openssl pcre zlib
    ] ++ stdenv.lib.optionals stdenv.isDarwin [ libiconv ];

  tools = [ pkgs.hostname llvm_suite.extra ];
in

pkgs.stdenv.mkDerivation rec {
  name = "crystal-dev";

  buildInputs = tools ++ stdLibDeps ++ [
    latestCrystalBinary
    pkgconfig
    llvm_suite.llvm
  ];

  CRYSTAL_LIBRARY_PATH = "${latestCrystalBinary}/lib";
  LLVM_CONFIG = "${llvm_suite.llvm}/bin/llvm-config";

  # ld: warning: object file (.../src/ext/libcrystal.a(sigfault.o)) was built for newer OSX version (10.14) than being linked (10.12)
  MACOSX_DEPLOYMENT_TARGET = "10.11";
}
