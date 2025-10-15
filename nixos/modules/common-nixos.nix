{ pkgs, lib, pkgs-unstable, inputs, modulesPath, ... }:
let inherit (inputs) self;

  # pubKeyDir = "./ssh_pub_keys";
  # pubKeyFiles = builtins.readDir pubKeyDir;
  # pubKeys = map (file: builtins.readFile "${pubKeyDir}/${file}") 
  #               (builtins.filter (name: lib.hasSuffix ".pub" name) pubKeyFiles);

  pubKeys = [
    # dobro
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"

    # impb
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/o9LEemdBD7Gw3nNf1qSydEiOXYZd5ItyhfzOgy+3s jono@foodnotblogs.com"

    # nixahi
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpHvDJmCp1AzPORZMCWbjC8yRGRUSzsUNoI+geHb3OI jono@foodnotblogs.com"

    # orc
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW4SMTIQQChTCFL/SJKkOp9mejFiCih0cNjT3mirFLcuuGPiH/jlp/h6312238Piea737cgbt0c70Jt1S7F/zmsKVU9rQPk/kluOoE5jMJLoOqZeUxxRmZVYs1ebxeSoI2MHQGv+9U0YjKMCvKfQfT5IDm9sjRtcfodo81RbUOayCvc3Kq4B6iUe1A4/UbNXlHEzsbIVpn3fcgzAYynuzCkQ/rzMfNwIz8JTs4oxs4WVo0hmCyqcrpQqsXUQ8OXrIim/EQaJgQp+1Y7c7r9eMjV3HzQBWfd4sKTROcAUXgff0uW6ieArIuugOnDjE/ipxI0n1b9PQGg1b0ZkqZo2Nj ssh-key-2025-02-18"
  ];          

in {

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.warn-dirty = false;

  nix.settings.trusted-public-keys = [
    "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
  ];

  system.stateVersion = lib.mkDefault "25.05";

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
  
  virtualisation.podman = {
    enable = true;
    # dockerCompat = true;
  };

  security = {
    doas.enable = true;
    sudo.enable = true;
  };

  services.envfs.enable = true;

  services.tailscale.enable = true;
  # trying unstable to see if it works around the test errors in 1.82.5
  services.tailscale.package = pkgs-unstable.tailscale;

  services.openssh = {
    enable = true;
    # authorizedKeysInHomedir = true;  # TODO: get this working so keys can live in home manager instead?
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  networking.firewall.enable = false;

  programs.fish.enable = true;
  programs.direnv.enable = true;

  programs.direnv.enableFishIntegration = true;

  programs.command-not-found.enable = false;

#   programs.neovim = {
#     enable = true;
#     viAlias = true;
#     vimAlias = true;
#   };

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

      openssh = {
        # enable = true;
        authorizedKeys.keys = pubKeys;
        # authorizedKeysInHomedir = true;
      };
      
    };

  };

  environment.systemPackages = with pkgs-unstable;
    [
      sudo
      home-manager

    ] ++ (with pkgs;
      [

        # keeping flox here for now since it may work differently on osx for example

        # inputs.flox.packages.${pkgs.system}.default
      ]);

}
