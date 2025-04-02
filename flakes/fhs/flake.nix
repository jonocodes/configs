{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Explicitly declare supported systems
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      
      # Create system-specific attribute sets
      forEachSystem = systems: f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      });
      
    in {
      packages = forEachSystem supportedSystems ({ pkgs }: {
        default = pkgs.buildFHSEnv {
          name = "flox-fhs";
          targetPkgs = pkgs: [ pkgs.ruby ];
          # runScript = "bash";
        };
      });

      devShells = forEachSystem supportedSystems ({ pkgs }: {
        default = pkgs.mkShell {
          buildInputs = [ self.packages.${pkgs.system}.default ];
        };
      });
    };
}
