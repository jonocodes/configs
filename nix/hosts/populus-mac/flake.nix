# Work mac nix config. handles packages, home dir, git config, shell config, dev setup

{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
    let
      configuration = { pkgs, ... }: {

        nixpkgs.config.allowUnfree = true;

        services.nix-daemon.enable = true;

        nix.settings.experimental-features = "nix-command flakes";

        nix.settings.trusted-users = [ "@admin" "jonofinger" ];

        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true; # default shell on catalina
        programs.fish.enable = true;

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 4;

        nixpkgs.hostPlatform = "aarch64-darwin";

        nix.configureBuildUsers = true;

        security.pam.enableSudoTouchIdAuth = true;

        users.users.jonofinger = {
          name = "jonofinger";
          home = "/Users/jonofinger";
          shell = pkgs.fish;
          # isNormalUser = true;
          # extraGroups = [ "admin" ];
        };

        home-manager.users.jonofinger = {

          programs.fish = {
            enable = true;

            shellInit = ''
              set -x DATA_DIR $HOME/sync/savr_data

              set -x POPULUS_ENVIRONMENT dev
              set -x POPULUS_DATACENTER us
            '';

            interactiveShellInit = ''
              set fish_greeting # Disable greeting

              eval "$(/opt/homebrew/bin/brew shellenv)"

              conda activate populus-env
            '';

            shellAbbrs = {
              cat = "bat";
              p = "ping dgt.is";
              ll = "ls -lah";
              speed = "iperf3 -v && curl -sL yabs.sh | bash -s -- -bfdg";
              "..." = "cd ../..";

              u =
                "cd ~/sync/configs/nix/hosts/populus-mac && nix flake update && nix run nix-darwin -- switch --flake .#jonofinger && cd -";
            };
          };

          # The home.stateVersion option does not have a default and must be set
          home.stateVersion = "23.11";

          programs.git = {
            enable = true;
            userName = "Jono";
            userEmail = "jono.finger@populus.ai";
            lfs.enable = true;

            diff-so-fancy.enable = true;

            extraConfig = { push = { autoSetupRemote = true; }; };
          };

          programs.ssh.enable = true;
          programs.ssh.matchBlocks = {
            "*" = {
              user = "jono";  # this is because my user on this mac is jonofinger
            };
          };

        };

        environment.systemPackages = with pkgs; [
          # fish
          jq
          bat
          htop
          micro
          just
          iperf3
          # nixfmt
          # nixfmt-rfc-style
          duckdb
          coreutils # needed for speedtest
          vscode
          obsidian
          devenv
        ];

        homebrew = {
          enable = true;
          onActivation.cleanup = "uninstall";
          onActivation.upgrade = true;

          brews = [ # formulas
            "fish"
            "pgbouncer"
            "httpie"
            "mas"
            "yarn"

            # from terminal Brewfile
            "go-task"
            "n"
            "pdm"
            "terraform"
            "virtualenv"
            "git-lfs"
            "devcontainer"

            # "wally" # not the right wally for keyboard controll

            # temp apps for trying
            "helix"
            "pyright" # python language server used by helix

          ];

          casks = [
            "google-chrome"
            # "balenaetcher"
            "firefox"
            "thunderbird"
            "tad"
            "slack"
            # TODO: syncthing, https://mynixos.com/nixpkgs/package/syncthing-tray
            "insomnium"
            # "authy"
            "element"
            "tailscale" # TODO: https://mynixos.com/nix-darwin/options/services.tailscale
            "ticktick"
            "bruno"
            "pycharm"
            "zap"
            "dbeaver-community"
            "iterm2"
            "spotify"
            "zoom"
            "keepassxc"
            "telegram"
            # "calibre"
            # "libreoffice" # had to manually install because of brew/download issue

            # populus dev
            "mambaforge"
            "google-cloud-sdk"

            # to mount ssh. this seems to require a bunch of elevated privilges
            #"macfuse" # also need to manually install this https://github.com/osxfuse/sshfs/releases

          ];

          # apps from the apple store 
          masApps = { "hp-smart-for-desktop" = 1474276998; };

        };
      };
    in {
      # Build darwin flake using:
      darwinConfigurations."jonofinger" = nix-darwin.lib.darwinSystem {
        modules = [

          configuration

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }

          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true; # Install Homebrew under the default prefix
              user = "jonofinger"; # User owning the Homebrew prefix
            };
          }

        ];

      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."jonofinger".pkgs;
    };
}
