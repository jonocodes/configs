{ pkgs, pkgs-unstable, lib, inputs, modulesPath, home-manager, ... }:
let
  # inherit (inputs) self;
  sshKeyDir = ./ssh_pub_keys;
  sshKeys = builtins.readDir sshKeyDir;

in {

  home.username = "jono";
  home.homeDirectory = "/home/jono";

  home.stateVersion = "24.11";

  nix.gc = {
    automatic = true;
    frequency = "daily";
    options = "--delete-older-than 7d";
  };


  home.file = lib.mapAttrs'
    (name: _: {
      name = ".ssh/${name}";
      value = { source = "${sshKeyDir}/${name}"; };
    })
    sshKeys;


  # TODO: patch home manager syncthing to be like nixos syncthing
  #  https://github.com/nix-community/home-manager/blob/master/modules/services/syncthing.nix
  #  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/syncthing.nix


  programs.fish = {
#       enable = true;

    shellInit = ''
      set -x EDITOR micro
      '';

    shellAbbrs = {

      cat = "bat";
      p = "ping dgt.is";

      "..." = "cd ../..";

      u-flatpak = "cd ~/sync/configs/flatpak && ./flatpak-compose-linux-amd64 apply -current-state=system";

      i-nixos = "nh os switch $HOME/sync/configs/nixos";

      u-nixos = "cd ~/sync/configs/nixos && sudo nixos-rebuild build --flake .#$hostname";

      u-nixos-nh = "nh os switch --update $HOME/sync/configs/nixos";

      i-home = "cd ~/sync/configs/home-manager && home-manager switch --flake .#$hostname && cd -";

      u-home = "cd ~/sync/configs/home-manager && nix flake update && home-manager switch --flake .#$hostname && cd -";
    };
  };

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };

  programs.git = {
    enable = true;
    userName = "Jono";
    userEmail = "jono@foodnotblogs.com";
    lfs.enable = true;
  };


  # favor apps to not use root for security
  # requires a logout of gnome after an install to show the launcher?
  home.packages = with pkgs-unstable;
    [

      #   system/terminal
      bat
      jq
      micro
      htop
      btop
      iotop
      wget
      file
      screen

      fishPlugins.z #  TODO: replace with zoxide, and import history
      encfs
      dig
      inetutils
      nmap
      iperf3
      pv
      helix
      lynx
      browsh
      unzip

      age # for sops encryption
      sops

      gnumake
      just

      parallel-disk-usage # pdu cli

      #   nix helpers
      nvd
      # rnix-lsp
      nh

      #   for mailcow
      # openssl

      comma  # run uninstalled apps ie > , xeyes

      #   nix binary runner helpers
      # nix-index
      # nix-locate
      # steam-run # x86 only
      # TODO: https://github.com/thiagokokada/nix-alien
      #   other methods: https://unix.stackexchange.com/questions/522822/different-methods-to-run-a-non-nixos-executable-on-nixos

    ] ++ (with pkgs; [

      # inputs.flox.packages.${pkgs.system}.default


    ]);

}
