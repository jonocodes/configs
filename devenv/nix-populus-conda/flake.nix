{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            # pkgs = nixpkgs.legacyPackages.${system};
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  packages = with pkgs; [
                    
                    #  cant get 3.10 to work right with conda
                    # python310
                    # python310Packages.pip

                    python311
                    python311Packages.pip
                    conda
                    pdm
                    nodejs_18
                    yarn
                    gnumake
                    go-task
                    terraform
                    (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
                    kubectl
                    google-cloud-sql-proxy

                    gcc
                    binutils

                  ];

                  env.POPULUS_DATACENTER = "us";
                  env.POPULUS_ENVIRONMENT = "dev";

                  scripts.con1.exec = ''conda-shell -c fish'';

                  # why doesnt this work?
                  scripts.con2.exec = ''conda activate populus-env'';

                  enterShell = ''

                    python -V
                    pdm -V

                    fish

                    # export CONDACONFIGDIR=""
                    # cd() { builtin cd "$@" && 
                    # if [ -f $PWD/.conda_config ]; then
                    #     export CONDACONFIGDIR=$PWD
                    #     conda activate $(cat .conda_config)
                    # elif [ "$CONDACONFIGDIR" ]; then
                    #     if [[ $PWD != *"$CONDACONFIGDIR"* ]]; then
                    #         export CONDACONFIGDIR=""
                    #         conda deactivate
                    #     fi
                    # fi }

                  '';

                }
              ];
            };
          });
    };
}
