{ pkgs, pkgs-unstable, lib, inputs, modulesPath, home-manager, ... }:
let

  syncthingIgnores = builtins.readFile ../files/syncthingIgnores.txt;

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

  home.file = lib.mkMerge [

    {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      "sync/savr_data/.stignore".text = syncthingIgnores;
    }

    (lib.mapAttrs'
      (name: _: {
        name = ".ssh/${name}";
        value = { source = "${sshKeyDir}/${name}"; };
      })
      sshKeys)
  ];

  # TODO: patch home manager syncthing to be like nixos syncthing
  #  https://github.com/nix-community/home-manager/blob/master/modules/services/syncthing.nix
  #  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/syncthing.nix


  programs.fish = {

    enable = true;

    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';

    shellInit = ''
      set -x EDITOR micro

      set -x FLAKE_OS $HOME/sync/configs/nixos
      set -x FLAKE_HOME $HOME/sync/configs/home-manager
      '';

    shellAbbrs = {

      cat = "bat";

      p = "ping dgt.is";

      "..." = "cd ../..";


      # TODO: clean up syncthing conflicts like so:
      # DIFFPROG=org.gnome.meld ./syncthing-resolve-conflicts -d ./common -f


    };

    shellAliases = {

      # to update run > i-home --update
      i-nixos = "nh os switch $FLAKE_OS";

      # to update home manager, run the following with '--update'
      i-home = "nh home switch $FLAKE_HOME";

      i = lib.mkDefault "i-nixos && i-home";
      u = lib.mkDefault "i-nixos --update && i-home --update";
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



  # may need to wait until 25.05 for syncthing in home manager to mature

  # failing at warning: failed to load external entity "/home/jono/.local/state/syncthing/config.xml"
  /* services.syncthing = {
         enable = true;
     #     user = "jono";
     #     dataDir = "/home/jono/sync2";
     #     configDir = "/home/jono/.config/syncthing2";

         # only in master, not home manager 24.11
     #    guiAddress = "0.0.0.0:8888";  # Custom port 8888

     #     tray.enable  = true;

         settings = {

           extraOptions = [
             "--data=/home/jono/sync2"
             "--config=/home/jono/.config/syncthing2"
           ];

           gui = {
             tls = false;
             theme = "default";
           };
           options = {
             listenAddresses = [ "tcp://0.0.0.0:22001" "quic://0.0.0.0:22001" ];
           };
     #       devices = {
     #         "device1" = {
     #           id = "DEVICE-ID-GOES-HERE";
     #           addresses = [ "dynamic" ];
     #         };
     #       };
           folders = {
             "downl" = {
               path = "/home/jono/Downloads";
     #           devices = [ "device1" ];
             };
           };
         };
       };
  */


  # favor apps to not use root for security
  # requires a logout of gnome after an install to show the launcher?
  home.packages = with pkgs-unstable;
    [

      # system, terminal
      bat
      jq
      file
      screen
      gnumake
      just
      unzip
      pv
      parallel-disk-usage # pdu cli
      fishPlugins.z #  TODO: replace with zoxide, and import history
      encfs

      # editors, networking
      htop
      btop
      iotop
      wget
      dig
      inetutils
      nmap
      iperf3
      speedtest-cli

      lynx
      browsh

      helix
      micro

      # nix helpers
      nvd
      # rnix-lsp
      nh
      comma  # run uninstalled apps ie > , xeyes
      age # for sops encryption
      sops

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
