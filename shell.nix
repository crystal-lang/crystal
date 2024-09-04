# This nix-shell script can be used to get a complete development environment
# for the Crystal compiler.
#
# You can choose which llvm version use and, on Linux, choose to use musl.
#
# $ nix-shell --pure
# $ nix-shell --pure --arg llvm 10
# $ nix-shell --pure --arg llvm 10 --arg musl true
# $ nix-shell --pure --arg llvm 9
# $ nix-shell --pure --arg llvm 9 --argstr system i686-linux
# ...
# $ nix-shell --pure --arg llvm 6
#
# If needed, you can use https://app.cachix.org/cache/crystal-ci to avoid building
# packages that are not available in Nix directly. This is mostly useful for musl.
#
# $ nix-env -iA cachix -f https://cachix.org/api/v1/install
# $ cachix use crystal-ci
# $ nix-shell --pure --arg musl true
#

{llvm ? 11, musl ? false, system ? builtins.currentSystem}:

let
  nixpkgs = import (builtins.fetchTarball {
    name = "nixpkgs-23.05";
    url = "https://github.com/NixOS/nixpkgs/archive/23.05.tar.gz";
    sha256 = "10wn0l08j9lgqcw8177nh2ljrnxdrpri7bp0g7nvrsn9rkawvlbf";
  }) {
    inherit system;
  };

  pkgs = if musl then nixpkgs.pkgsMusl else nixpkgs;
  llvmPackages = pkgs."llvmPackages_${toString llvm}";

  genericBinary = { url, sha256 }:
    pkgs.stdenv.mkDerivation rec {
      name = "crystal-binary";
      src = builtins.fetchTarball { inherit url sha256; };

      # Extract only the compiler binary
      buildCommand = ''
        mkdir -p $out/bin

        # Darwin packages use embedded/bin/crystal
        [ ! -f "${src}/embedded/bin/crystal" ] || cp ${src}/embedded/bin/crystal $out/bin/

        # Linux packages use lib/crystal/bin/crystal
        [ ! -f "${src}/lib/crystal/bin/crystal" ] || cp ${src}/lib/crystal/bin/crystal $out/bin/
      '';
    };

  # Hashes obtained using `nix-prefetch-url --unpack <url>`
  latestCrystalBinary = genericBinary ({
    x86_64-darwin = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.13.2/crystal-1.13.2-1-darwin-universal.tar.gz";
      sha256 = "sha256:046zlsyrj1i769xh4jvv0a81nlqj7kiz0hliq1za86k1749kcmlz";
    };

    aarch64-darwin = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.13.2/crystal-1.13.2-1-darwin-universal.tar.gz";
      sha256 = "sha256:046zlsyrj1i769xh4jvv0a81nlqj7kiz0hliq1za86k1749kcmlz";
    };

    x86_64-linux = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.13.2/crystal-1.13.2-1-linux-x86_64.tar.gz";
      sha256 = "sha256:0186q0y97135kvxa8bmzgqc24idv19jg4vglany0pkpzy8b3qs0s";
    };
  }.${pkgs.stdenv.system});

  boehmgc = pkgs.boehmgc.override {
    enableLargeConfig = true;
  };

  stdLibDeps = with pkgs; [
      boehmgc gmp libevent libiconv libxml2 libyaml openssl pcre2 zlib
    ] ++ lib.optionals stdenv.isDarwin [ libiconv ];

  tools = [ pkgs.hostname pkgs.git llvmPackages.bintools ] ++ pkgs.lib.optional (!llvmPackages.lldb.meta.broken) llvmPackages.lldb;
in

pkgs.stdenv.mkDerivation rec {
  name = "crystal-dev";

  buildInputs = tools ++ stdLibDeps ++ [
    latestCrystalBinary
    pkgs.pkg-config
    llvmPackages.libllvm
    pkgs.libffi
  ];

  LLVM_CONFIG = "${llvmPackages.libllvm.dev}/bin/llvm-config";

  MACOSX_DEPLOYMENT_TARGET = "10.11";
}
