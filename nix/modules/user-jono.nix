{ config, lib, pkgs, ... }:
{

    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.11";

    nix.gc = {
      automatic = true;
      frequency = "daily";
      options = "--delete-older-than 7d";
    };

    # fonts.fontconfig.enable = false;

    # home.file.".thunderbird".source = config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    # home.file = {
    #   "sync/common/.stignore".text = syncthingIgnores;
    #   "sync/configs/.stignore".text = syncthingIgnores;
    #   "sync/more/.stignore".text = syncthingIgnores;
    #   "sync/savr_data/.stignore".text = syncthingIgnores;      
    # };

    # apps specific to this host
    # home.packages = with pkgs-unstable;
    # [
    #   android-studio
    #   # nodejs_22
    # ] ++ (with pkgs; [
    #   # android-studio # very old version, 2023
    #   # android-studio-full  # this takes so long to install because it has to build arm v8 every time
    # ]);


    programs.fish = {
      enable = true;

      shellInit = ''
        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

#        set -x POPULUS_ENVIRONMENT dev
#        set -x POPULUS_DATACENTER us

        set -x EDITOR micro

        # set -x NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE 1

        ## Android
        set --export ANDROID_HOME $HOME/Android/Sdk
        set -gx PATH $ANDROID_HOME/emulator $PATH;
        set -gx PATH $ANDROID_HOME/tools $PATH;
        set -gx PATH $ANDROID_HOME/tools/bin $PATH;
        set -gx PATH $ANDROID_HOME/platform-tools $PATH;
      '';

      interactiveShellInit = ''
        set fish_greeting # Disable greeting

        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        # conda-shell -c fish
      '';

      shellAbbrs = {
        cat = "bat";
        p = "ping nixos.org";

        "..." = "cd ../..";

        u = "sudo date && os-update && time os-build && os-switch";

        # pop-devenv = "nix develop --impure path:$HOME/sync/configs/devenv/nix-populus-conda";

        # conda-populus =
        #   "conda activate populus-env && alias python=$HOME/.conda/envs/populus-env/bin/python";

      };

      shellAliases = {

        # update the checksum of the repos
        os-update = "cd $HOME/sync/configs/nix && nix flake update && cd -";

        # list incoming changes, compile, but dont install/switch to them
        os-build =
          "nix build --out-link /tmp/result --dry-run $HOME/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nix build --out-link /tmp/result $HOME/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake $HOME/sync/configs/nix --impure";

      };

    };

    programs.git = {
      enable = true;
      userName = "Jono";
      userEmail = "jono@foodnotblogs.com";
      lfs.enable = true;
    };

  }

  