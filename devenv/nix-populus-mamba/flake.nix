{

  # this is intended to be the micromamba (instead of conda) version that uses FHS
  # when I left off, this was causing an infinate loop in direnv

  # to run without .envrc:
  #   NIXPKGS_ALLOW_UNFREE=1 nix develop ~/sync/more/configs/nix-populus-dev-v3/ --impure
  # still does not preserve fish shell or conda environment


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

# installationPath = "~/.conda";
    in
    {

      # does not work. I want an alias from conda to micromamba
      scripts.ex.exec = ''
        curl "https://httpbin.org/get?$1" | jq '.args'
      '';

      devShell.x86_64-linux = (pkgs.buildFHSUserEnv {
        name = "arst";

        targetPkgs = pkgs: (
          with pkgs; [
            autoconf
            gnumake
            micromamba
            pdm

            nodejs_18
            yarn
            go-task
            kubectl
            
            (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
            # terraform
          ]
        );
        profile = ''
          # export LD_LIBRARY_PATH=rast
          export J11=123
          alias ctest="python -c 'from populus_lib import config; print(config.db.get_host())'"

          set -e
          export MAMBA_ROOT_PREFIX=${builtins.getEnv "PWD"}/.mamba
          eval "$(micromamba shell hook --shell=bash | sed 's/complete / # complete/g')"
          micromamba create --yes -q -n populus-env
          micromamba activate populus-env
          micromamba info
          set +e

#          conda activate populus-env
          conda info

          pdm --version

        '';

      }).env;
    
        # does not work
        shellHook = ''
          echo HELLO
          micromamba --version
          alias ctest2="python -c 'from populus_lib import config; print(config.db.get_host())'"

        '';
        
    };
}
