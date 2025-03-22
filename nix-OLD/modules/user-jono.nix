{ config, lib, pkgs, ... }:
{

    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.11";

    nix.gc = {
      automatic = true;
      frequency = "daily";
      options = "--delete-older-than 7d";
    };

    # # cant really do this here since its nested. dang
    # users.users = {

    #   jono = {
    #     isNormalUser = true;
    #     description = "jono";
    #     extraGroups = [ "networkmanager" "wheel" "docker" ];
    #     shell = pkgs.fish;

    #     openssh.authorizedKeys.keys = [
    #       # dobro
    #       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"
    #       # oracle
    #       "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW4SMTIQQChTCFL/SJKkOp9mejFiCih0cNjT3mirFLcuuGPiH/jlp/h6312238Piea737cgbt0c70Jt1S7F/zmsKVU9rQPk/kluOoE5jMJLoOqZeUxxRmZVYs1ebxeSoI2MHQGv+9U0YjKMCvKfQfT5IDm9sjRtcfodo81RbUOayCvc3Kq4B6iUe1A4/UbNXlHEzsbIVpn3fcgzAYynuzCkQ/rzMfNwIz8JTs4oxs4WVo0hmCyqcrpQqsXUQ8OXrIim/EQaJgQp+1Y7c7r9eMjV3HzQBWfd4sKTROcAUXgff0uW6ieArIuugOnDjE/ipxI0n1b9PQGg1b0ZkqZo2Nj ssh-key-2025-02-18"
    #     ];
    #   };

    # };


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



    # environment.sessionVariables = {
    #   FLAKE = "$HOME/sync/configs/nix";
    # };


    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 7d --keep 3";
      flake = "/home/jono/sync/configs/nix";
    };


    programs.fish = {
      enable = true;

      shellInit = ''

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
      '';

      shellAbbrs = {
        cat = "bat";
        p = "ping nixos.org";

        "..." = "cd ../..";

        u-old = "sudo date && os-update && time os-build && os-switch";

        u = "sudo date && nh os switch --update";

        # pop-devenv = "nix develop --impure path:$HOME/sync/configs/devenv/nix-populus-conda";

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

  