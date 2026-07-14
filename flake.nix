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
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});

      # Fragments the confirmator DETECTS for this repo (git-tracked .nix/.sh/
      # .md/.yml). lefthook.yml + the wrapper set on PATH are materialized from
      # exactly these so `nix run .#confirm` fidelity/coherence hold.
      matFragments = [
        "base"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];

      # Fragments promoted to PINNED hermetic `nix flake check` gates. A subset
      # of matFragments: only tools with pinned-check equivalents.
      checkFragments = [
        "base"
        "nix"
        "shell"
        "ascii"
      ];
    in
    {
      lib = {
        formatVersion = 1;
      };

      packages = forAllSystems (pkgs: {
        set = set-and-setting.lib.mkSet { inherit pkgs; };
        setting = (set-and-setting.lib.mkSetting { inherit pkgs; }).materialized;
      });

      devShells = forAllSystems (
        pkgs:
        let
          sys = pkgs.stdenv.hostPlatform.system;
          mat = set-and-setting.lib.materializationFor {
            inherit pkgs;
            fragments = matFragments;
          };
          shells = set-and-setting.lib.mkDevShells {
            inherit pkgs;
            basePackages = mat.packages ++ [
              pkgs.coreutils
              pkgs.git
              pkgs.jq
              pkgs.nix
              pkgs.gh
              pkgs.bats
            ];
            defaultShellHook = ''
              ${self.packages.${sys}.setting}/bin/sync-setting .
              cp -f ${mat.files}/lefthook.yml lefthook.yml
            '';
            agenticShellHook = ''
              ${self.packages.${sys}.setting}/bin/sync-setting .
              cp -f ${mat.files}/lefthook.yml lefthook.yml
              ${self.packages.${sys}.set}/bin/sync-set .
            '';
          };
          # nix-lefthook-ci-action's install step uses
          # nix develop --ignore-environment without --keep HOME;
          # git fatally errors when HOME is unset. Guard every shell.
          guardHome =
            shell:
            shell.overrideAttrs (prev: {
              shellHook = ''
                export HOME="''${HOME:-/tmp}"
              ''
              + prev.shellHook;
            });
        in
        builtins.mapAttrs (_: guardHome) shells
      );

      # #93: fragment-driven checks -- declare fragments once, get all relevant
      # pinned checks.
      checks = forAllSystems (
        pkgs:
        (set-and-setting.lib.checksFor {
          inherit pkgs;
          src = ./.;
          fragments = checkFragments;
        })
        // {
          dep-graph = set-and-setting.lib.mkDepGraphCheck {
            inherit pkgs;
            projectRoot = ./.;
          };
          default = pkgs.runCommand "checks" { } "touch $out";
        }
      );

      # #94: post-materialization acceptance gate. `guardrails.yml` runs this
      # after `nix develop` materializes configs, before `nix flake check`.
      apps = forAllSystems (
        pkgs:
        let
          sys = pkgs.stdenv.hostPlatform.system;
          mat = set-and-setting.lib.materializationFor {
            inherit pkgs;
            fragments = matFragments;
          };
        in
        {
          confirm = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "confirm";
                runtimeInputs = mat.packages ++ [
                  pkgs.coreutils
                  pkgs.diffutils
                  pkgs.findutils
                  pkgs.gawk
                  pkgs.git
                  pkgs.gnugrep
                ];
                text = ''
                  export FRAGMENTS_DIR="${set-and-setting}/setting/integrations/lefthook"
                  export ASSEMBLE_SCRIPT="${set-and-setting}/setting/lib/assemble-lefthook.sh"
                  export DETECT_SCRIPT="${set-and-setting}/setting/lib/detect-fragments.sh"
                  export SETTING_SRC="${self.packages.${sys}.setting}"
                  export CONFIRM_SCRIPT="${set-and-setting}/lib/confirm.sh"
                  export CONFIRM_REV="${set-and-setting.rev or "unknown"}"
                  bash "$CONFIRM_SCRIPT"
                '';
              }
            }/bin/confirm";
          };
        }
      );
    };
}
