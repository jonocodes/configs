# Network topology configuration for nix-topology
# This defines external devices and networks that can't be auto-detected from NixOS configs
#
# Build diagrams with: nix build .#topology.x86_64-linux.config.output
# SVG outputs will be in ./result/

{ config, lib, ... }: {

  # ============================================================================
  # Networks
  # ============================================================================

  networks.home = {
    name = "Home Network";
    cidrv4 = "192.168.30.0/24";
  };

  networks.berk = {
    name = "Berk Network (Offsite)";
    cidrv4 = "192.168.1.0/24";
  };

  networks.lemon = {
    name = "Lemon Network (Offsite)";
  };

  networks.oracle = {
    name = "Oracle Cloud";
  };

  networks.tailscale = {
    name = "Tailscale Tailnet";
    cidrv4 = "100.64.0.0/10";
  };

  # ============================================================================
  # Internet Node
  # ============================================================================

  nodes.internet = {
    deviceType = "internet";
    interfaces.eth0 = {};
  };

  # ============================================================================
  # Non-NixOS Devices
  # ============================================================================

  # Home network router
  nodes.opnsense = {
    deviceType = "router";
    hardware.info = "MiniPC N100 - OPNsense";
    interfaces.wan = {
      physicalConnections = [{ node = "internet"; interface = "eth0"; }];
    };
    interfaces.lan = {
      network = "home";
      physicalConnections = [
        { node = "dobro"; interface = "eth0"; }
        { node = "zeeba"; interface = "eth0"; }
        { node = "plex"; interface = "eth0"; }
      ];
    };
  };

  # TODO: add access point, cameras, 

  # Home NAS (no tailscale)
  nodes.nas = {
    deviceType = "device";
    hardware.info = "Home NAS";
    interfaces.eth0.network = "home";
  };

  # Berkeley offsite NAS (no tailscale, routed via matcha)
  nodes.berknas = {
    deviceType = "device";
    hardware.info = "Offsite NAS (routed via Matcha)";
    interfaces.eth0 = {
      network = "berk";
      physicalConnections = [{ node = "matcha"; interface = "eth0"; }];
    };
  };

  # Raspberry Pi at lemon network
  nodes.choco = {
    deviceType = "device";
    hardware.info = "Raspberry Pi 3B - Arch Linux";
    interfaces.eth0.network = "lemon";
    interfaces.tailscale0.network = "tailscale";
    services.syncthing.name = "Syncthing";
  };

  # Work laptop (macOS)
  nodes.jonodot = {
    deviceType = "device";
    hardware.info = "Apple M4 - macOS";
    interfaces.tailscale0.network = "tailscale";
    services.syncthing.name = "Syncthing";
  };

  # Phone
  nodes.galaxys23 = {
    deviceType = "device";
    hardware.info = "Samsung Galaxy S23";
    interfaces.tailscale0.network = "tailscale";
    services.syncthing.name = "Syncthing";
  };

  # ============================================================================
  # NixOS Host Topology Overrides
  # These add extra info that can't be auto-detected from NixOS configs
  # ============================================================================

  # Workstation
  nodes.dobro = {
    deviceType = "nixos";
    hardware.info = "Desktop i7-6700K, 64GB RAM, ZFS";
    interfaces.eth0.network = "home";
    interfaces.tailscale0.network = "tailscale";
  };

  # Home server
  nodes.zeeba = {
    deviceType = "nixos";
    hardware.info = "Xeon 1U Server, 32GB RAM, ZFS";
    interfaces.eth0.network = "home";
    interfaces.tailscale0 = {
      network = "tailscale";
      # Zeeba is an exit node
    };
  };

  # Backup router (offline)
  nodes.plex = {
    deviceType = "nixos";
    hardware.info = "Dell Optiplex 9010 (offline)";
    interfaces.eth0.network = "home";
  };

  # Berkeley minipc - subnet router
  nodes.matcha = {
    deviceType = "nixos";
    hardware.info = "MiniPC N100 - Subnet Router";
    interfaces.eth0.network = "berk";
    interfaces.tailscale0.network = "tailscale";
  };

  # Oracle cloud VM
  nodes.orc = {
    deviceType = "nixos";
    hardware.info = "ARM Cloud Server";
    interfaces.eth0.network = "oracle";
    interfaces.tailscale0.network = "tailscale";
  };

  # Laptops
  nodes.imbp = {
    deviceType = "nixos";
    hardware.info = "Apple i5 MacBook Pro";
    interfaces.tailscale0.network = "tailscale";
  };

  nodes.nixahi = {
    deviceType = "nixos";
    hardware.info = "Apple M1 - NixOS Asahi";
    interfaces.tailscale0.network = "tailscale";
  };

  nodes.lute = {
    deviceType = "nixos";
    hardware.info = "Lute Host";
    interfaces.eth0.network = "home";
    interfaces.tailscale0.network = "tailscale";
  };

}
