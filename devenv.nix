{ pkgs, lib, config, inputs, ... }:

{
  dotenv.enable = true;

  git-hooks.hooks = {
    actionlint.enable = true;
    check-toml.enable = true;
    check-vcs-permalinks.enable = true;
    circleci.enable = true;
    crystal.enable = true;
    markdownlint.enable = true;
    reuse.enable = true;
    shellcheck = {
      enable = true;
      excludes = [
        ".*\.zsh$"
      ];
    };
    typos.enable = true;
  };
}
