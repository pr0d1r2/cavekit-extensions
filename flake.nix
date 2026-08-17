{
  description = "cavekit-extensions";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      src = ./.;
      extraChecks = pkgs: {
        # Keep actionlint in the CI gate while avoiding the shared helper's
        # pathPrefix bug (sourceByRegex now requires a list of regexes).
        actionlint = set-and-setting.lib.mkLefthookCheck {
          inherit pkgs;
          name = "actionlint";
          wrapper = builtins.elemAt
            (set-and-setting.lib.materializationFor {
              inherit pkgs;
              fragments = [ "actions" ];
            }).packages
            0;
          src = nixpkgs.lib.sources.sourceByRegex ./. [ "^\\.github/workflows/.*" ];
          suffices = [ ".yml" ".yaml" ];
        };
      };
    };
}
