{
  description = "An FHS shell with conda";

  # found here: https://gist.github.com/ChadSki/926e5633961c9b48131eabd32e57adb2

  # TODO: autoloading makes infinate loop

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Conda installs it's packages and environments under this directory
      installationPath = "~/.conda";

      initScript = pkgs.writeScript "docspell-build-init" ''

          echo after; conda activate populus-env; alias arst2='123'


          #export LD_LIBRARY_PATH=
          echo init
          # ${pkgs.bash}/bin/bash -c "sbt -mem 4096 -java-home ${pkgs.openjdk17}/lib/openjdk"
        '';

      # Downloaded Miniconda installer
      minicondaScript = pkgs.stdenv.mkDerivation rec {
        name = "miniconda-${version}";
        version = "4.3.11";
        src = pkgs.fetchurl {
          url = "https://repo.continuum.io/miniconda/Miniconda3-${version}-Linux-x86_64.sh";
          sha256 = "1f2g8x1nh8xwcdh09xcra8vd15xqb5crjmpvmc2xza3ggg771zmr";
        };
        # Nothing to unpack.
        unpackPhase = "true";
        # Rename the file so it's easier to use. The file needs to have .sh ending
        # because the installation script does some checks based on that assumption.
        # However, don't add it under $out/bin/ becase we don't really want to use
        # it within our environment. It is called by "conda-install" defined below.
        installPhase = ''
          mkdir -p $out
          cp $src $out/miniconda.sh
        '';
        # Add executable mode here after the fixup phase so that no patching will be
        # done by nix because we want to use this miniconda installer in the FHS
        # user env.
        fixupPhase = ''
          chmod +x $out/miniconda.sh
        '';
      };

      # Wrap miniconda installer so that it is non-interactive and installs into the
      # path specified by installationPath
      conda = pkgs.runCommand "conda-install"
        { buildInputs = [ pkgs.makeWrapper minicondaScript ]; }
        ''
          mkdir -p $out/bin
          makeWrapper                            \
            ${minicondaScript}/miniconda.sh      \
            $out/bin/conda-install               \
            --add-flags "-p ${installationPath}" \
            --add-flags "-b"
        '';

    in {
      devShell.x86_64-linux = (pkgs.buildFHSUserEnv {
        name = "conda";
        targetPkgs = pkgs: (
          with pkgs; [

            pdm
            nodejs_18
            yarn
            go-task
            kubectl
            (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
            # terraform

            autoconf
            binutils
            conda
            curl
            gnumake
            zlib
          ]
        );
        profile = ''
          # conda
          export PATH=${installationPath}/bin:$PATH
          export NIX_CFLAGS_COMPILE="-I${installationPath}/include"
          export NIX_CFLAGS_LINK="-L${installationPath}lib"
          conda env list
          echo profile
        '';

        # runScript ="fish";

        # runScript="exec fish -C " + initScript;
        
        runScript = pkgs.writeScript "init3.sh" ''
          echo run script
function l2
  ls -l
end
          exec fish -C l2'';


        # runScript = pkgs.writeScript "init3.sh" ''
        #   echo run script
        #   exec fish -C "echo after; conda activate populus-env; alias arst2='123'"
        # '';

      }).env;
    };
}
