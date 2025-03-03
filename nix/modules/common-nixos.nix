{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let inherit (inputs) self;
in {


    # localpackages = import ./pkgs {
    #   # inherit pkgs;
    #   # pkgs = pkgs.legacyPackages;
    # };


#   nixpkgs.config.allowUnfree = true;



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


  # move this into user-jono
  users.users = {

    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.fish;

      openssh.authorizedKeys.keys = [
        # dobro
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"

        # oracle, shared key - probably dont need this any more
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW4SMTIQQChTCFL/SJKkOp9mejFiCih0cNjT3mirFLcuuGPiH/jlp/h6312238Piea737cgbt0c70Jt1S7F/zmsKVU9rQPk/kluOoE5jMJLoOqZeUxxRmZVYs1ebxeSoI2MHQGv+9U0YjKMCvKfQfT5IDm9sjRtcfodo81RbUOayCvc3Kq4B6iUe1A4/UbNXlHEzsbIVpn3fcgzAYynuzCkQ/rzMfNwIz8JTs4oxs4WVo0hmCyqcrpQqsXUQ8OXrIim/EQaJgQp+1Y7c7r9eMjV3HzQBWfd4sKTROcAUXgff0uW6ieArIuugOnDjE/ipxI0n1b9PQGg1b0ZkqZo2Nj ssh-key-2025-02-18"

        # populus mac
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDc7mCQOFHhXTbenLwIPG3MMqy3bi1kmu00fjUJ5saf jono.finger@populus.ai"
      ];
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

      gnumake
      just

      parallel-disk-usage # pdu cli


      #   nix helpers
      nvd
      # nh
      # rnix-lsp

      #   for mailcow
      openssl

      comma  # run uninstalled apps ie > , xeyes

      #   short term dev projects
      # tcpdump
      # ngrep

      #   nix binary runner helpers
      # nix-index
      # nix-locate
      # steam-run # x86 only
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
        # inputs.flox.packages.${pkgs.system}.default
        cifs-utils
      ]);

}
