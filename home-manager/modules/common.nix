{ pkgs, pkgs-unstable, lib, inputs, modulesPath, home-manager, ... }:
let

  syncthingIgnores = builtins.readFile ../files/syncthingIgnores.txt;
  
in {

  home.username = "jono";
  home.homeDirectory = "/home/jono";

  home.stateVersion = lib.mkDefault "25.05";

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

      # ".ssh/authorized_keys" = {
      #   text = pubKeys;
      # };
    }

    # (lib.mapAttrs'
    #   (name: _: {
    #     name = ".ssh/${name}";
    #     value = { source = "${sshKeyDir}/${name}"; };
    #   })
    #   sshKeys)
  ];


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



      # or use git-merge! https://www.rafa.ee/articles/resolve-syncthing-conflicts-using-three-way-merge/


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

    # extraConfig = ''
    #   # Auto-include all keys
    #   ${lib.concatMapStrings (key: key + "\n") pubKeys}
    # '';
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
      fishPlugins.z # using this instead of zoxide since I prefer its tab completion
      encfs
      lsof

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
