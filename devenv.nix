{ pkgs, lib, config, inputs, ... }:
let
  # The locked nixpkgs still packages Ameba 1.6.4 with Crystal 1.17.
  ameba = (pkgs.ameba.override { crystal_1_17 = pkgs.crystal_1_19; }).overrideAttrs (_: rec {
    version = "1.7.0";
    src = pkgs.fetchFromGitHub {
      owner = "crystal-ameba";
      repo = "ameba";
      tag = "v${version}";
      hash = "sha256-P2XirYKxq3Y6cjK5O013fPzag9uWR9jdetlLxX70ji4=";
    };
  });
in
{
  dotenv.enable = true;

  scripts = {
    "asciidoc-linter".exec = "${pkgs.uv}/bin/uv tool run --from git+https://github.com/docToolchain/asciidoc-linter/@52e7fa5982d980eefd5b548f68ff6f58767fe772 asciidoc-linter $@";
  };

  git-hooks.hooks = {
    asciidoc-linter = {
      enable = true;
      name = "Asciidoc Linter";
      entry = "asciidoc-linter --format plain";
      files = "\\.adoc$";
      #pass_filenames = true;
    };
    ameba = {
      enable = true;
      name = "Ameba";
      entry = "${ameba}/bin/ameba --fix";
      files = "\\.cr$";
      excludes = ["^lib/"];
      pass_filenames = true;
    };
    check-toml.enable = true;
    check-vcs-permalinks.enable = true;
    circleci.enable = true;
    crystal.enable = true;
    makefile_both = {
      enable = true;
      name = "Change both Makefile and Makefile.win";
      entry = ''${pkgs.runtimeShell} -c 'test "$#" -ne 1 || (echo "Changes only in $@" && false)' --'';
      files = "^Makefile(\.win)?$";
      pass_filenames = true;
    };
    mbake = {
      enable = true;
      name = "Mbake";
      entry = "${pkgs.mbake}/bin/mbake format --config .mbake.toml";
      files = "Makefile|.*\\.Makefile|Makefile\\..*|.*\\.mk";
      pass_filenames = true;
    };
    rumdl.enable = true;
    shellcheck = {
      enable = true;
      excludes = [
        ".*\.zsh$"
      ];
    };
    shfmt = {
      enable = true;
      settings = {
        indent = 2;
        case-indent = true;
        simplify = false;
      };
      excludes = ["^lib/"];
    };
    typos.enable = true;
    zizmor.enable = true;
  };

  profiles = {
    lint.module = {
      # More expensive hooks that we don't want to execute on every commit all the time
      git-hooks.hooks = {
        # reuse always runs on all files in the repo which takes some time.
        # Violations are very rare, so a longer feedback loop doesn't matter much.
        reuse.enable = true;
      };
    };
  };
}
