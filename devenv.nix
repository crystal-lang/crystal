{ pkgs, lib, config, inputs, ... }:

{
  dotenv.enable = true;

  git-hooks.hooks = {
    actionlint.enable = true;
    ameba = {
      enable = true;
      name = "Ameba";
      entry = "${pkgs.ameba}/bin/ameba --fix";
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
    markdownlint.enable = true;
    shellcheck = {
      enable = true;
      excludes = [
        ".*\.zsh$"
      ];
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
