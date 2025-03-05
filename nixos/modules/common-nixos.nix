{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let inherit (inputs) self;
in {

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

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 3";
    # flake = "/home/jono/sync/config/nixos";
  };

#     nix.gc = {
#       automatic = true;
#       frequency = "daily";
#       options = "--delete-older-than 7d";
#     };

  users.users = {

    jono = {
      isNormalUser = true;
       extraGroups = [ "networkmanager" "wheel" "docker" ];
       shell = pkgs.fish;
    };

  };

  environment.systemPackages = with pkgs-unstable;
    [
      sudo
      home-manager

    ] ++ (with pkgs;
      [

        # keeping flox here for now since it may work differently on osx for exanple

        inputs.flox.packages.${pkgs.system}.default
#         cifs-utils
      ]);

}
