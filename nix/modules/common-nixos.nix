{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let inherit (inputs) self;
in {


    # localpackages = import ./pkgs {
    #   # inherit pkgs;
    #   # pkgs = pkgs.legacyPackages;
    # };


  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.warn-dirty = false;

  nix.settings.trusted-public-keys = [
    "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
  ];

  system.stateVersion = "24.11";

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  # let nix commands follow system nixpkgs revision
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # NOTE: you can then test any package in a nix shell, such as
  # $ nix shell nixpkgs#neovim

  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;

  networking.networkmanager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;

  security = {
    doas.enable = true;
    sudo.enable = true;
  };

  services.envfs.enable = true;

  services.tailscale.enable = true;

  services.openssh.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  networking.firewall.enable = false;

  programs.fish.enable = true;
  programs.direnv.enable = true;

  programs.command-not-found.enable = false;

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  users.users = {

    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.fish;
    };

  };

  # favor apps to not use root for security
  # requires a logout of gnome after an install to show the launcher?
  home-manager.users.jono.home.packages = with pkgs-unstable;
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
      age # for sops encryption
      sops

      parallel-disk-usage # pdu cli


      #   nix helpers
      nvd
      # rnix-lsp

      #   for mailcow
      openssl

      #   short term dev projects
      # tcpdump
      # ngrep

      #   nix binary runner helpers
      # nix-index
      # nix-locate
      steam-run # did not work for windsurf
      # TODO: https://github.com/thiagokokada/nix-alien
      #   other methods: https://unix.stackexchange.com/questions/522822/different-methods-to-run-a-non-nixos-executable-on-nixos

    ] ++ (with pkgs; [

      # pdm # this is here since when in flox the version, and pdm install fails. pdm 2.22.1

      # cifs-utils

    ]);

  environment.systemPackages = with pkgs-unstable;
    [

      sudo

      # cant get extensions.gnome.org properly integrated
      # manually install from there server-status-indicator, tailscale status
      # gnome-browser-connector
      # gnomeExtensions.appindicator
      # gnomeExtensions.server-status-indicator

    ] ++ (with pkgs;
      [
        inputs.flox.packages.${pkgs.system}.default
        cifs-utils
      ]);

}
