{ pkgs, config, ... }:
{

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    # enable if you also want IPv6 routing:
    # "net.ipv6.conf.all.forwarding" = true;

    # Disable reverse path filtering - required for NAT to work properly
    # Tailscale sets this to strict (2) which breaks forwarding
    # Must be set on ALL interfaces to override Tailscale's settings
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
    "net.ipv4.conf.enp1s0.rp_filter" = 0;
    "net.ipv4.conf.enp2s0.rp_filter" = 0;
    "net.ipv4.conf.tailscale0.rp_filter" = 0;
    "net.ipv4.conf.lo.rp_filter" = 0;

    # Increase network performance for router workload
    # Helps reduce RX packet drops and time_squeeze events
    "net.core.netdev_budget" = 600;        # default 300
    "net.core.netdev_budget_usecs" = 4000; # default 2000
    "net.core.netdev_max_backlog" = 5000;  # default 1000
  };

  # # Fix e1000e hardware unit hang on enp1s0 (WAN interface)
  # # Disable power management, adjust interrupt moderation, and disable offloading
  # boot.kernelParams = [
  #   "e1000e.InterruptThrottleRate=1"  # Disable interrupt throttling (1 = off)
  # ];

  # # Disable power management and offloading for e1000e interface to prevent hardware hangs
  # services.udev.extraRules = ''
  #   # Disable power management for e1000e (enp1s0) to prevent hardware unit hangs
  #   ACTION=="add", SUBSYSTEM=="net", DRIVERS=="e1000e", ATTR{power/control}="on"
  #   ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp1s0", RUN+="${pkgs.bash}/bin/bash -c 'echo 0 > /sys/class/net/%k/device/power/autosuspend_delay_ms 2>/dev/null || true'"
    
  #   # Disable offloading features that can cause hardware hangs
  #   ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp1s0", RUN+="${pkgs.ethtool}/bin/ethtool -K %k tso off gso off gro off lro off 2>/dev/null || true"
  #   ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp1s0", RUN+="${pkgs.ethtool}/bin/ethtool -A %k autoneg off rx off tx off 2>/dev/null || true"
  # '';

  # Install ethtool for udev rules and helper scripts
  environment.systemPackages = with pkgs; [
    ethtool
    socat  # For querying Kea control socket
    # jq     # For parsing JSON responses
    
    # # Helper script to list DHCP leases
    # (writeShellScriptBin "kea-leases" ''
    #   echo '{ "command": "lease4-get-all" }' | \
    #     sudo ${socat}/bin/socat - UNIX-CONNECT:/run/kea/kea4-ctrl-socket 2>/dev/null | \
    #     ${jq}/bin/jq -r '
    #       if .[0].result == 0 then
    #         .[0].arguments.leases[] | 
    #         "\(.["ip-address"])\t\(.hostname // "N/A")\t\(.["hw-address"])"
    #       else
    #         "Error: " + (.[0].text // "Unknown error")
    #       end
    #     '
    # '')
  ];

  services.inadyn = {
    enable = true;
    configFile = "/etc/inadyn.conf";
  };
  
  services.dnsmasq = {
    enable = true;
    settings = {
      no-resolv = true;
      # Don't read /etc/hosts - prevents returning 127.0.0.2 for local hostname
      no-hosts = true;
      server = [ "1.1.1.1" "8.8.8.8" ];
      interface = "enp2s0";
      bind-interfaces = true;
      cache-size = 1000;

      # Split-horizon DNS entries - resolve to zeeba's internal IP for LAN clients
      address = [
        "/digit.us.to/192.168.30.114"
        "/dgt.rokeachphoto.com/192.168.30.114"
        "/zeeba.dgt.is/192.168.30.114"
        "/a.dgt.is/192.168.30.114"
      ];

      log-queries = true;
    };
  };


  # enp1s0 = WAN (internet)
  # enp2s0 = LAN (local network)

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "enp2s0" ];  # your LAN NIC
      };

      # Control socket for querying leases via API
      control-socket = {
        socket-type = "unix";
        socket-name = "/run/kea/kea4-ctrl-socket";
      };

      # Load hook library for lease commands
      hooks-libraries = [
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_lease_cmds.so";
        }
      ];

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      subnet4 = [{
        id = 1;
        subnet = "192.168.30.0/24";
        interface = "enp2s0";

        pools = [{
          pool = "192.168.30.100 - 192.168.30.200";
        }];

        option-data = [
          {
            name = "routers";
            data = "192.168.30.1";  # router IP on LAN
          }
          {
            name = "domain-name-servers";
            # Point DHCP clients to plex for split-horizon DNS
            data = "192.168.30.1";
          }
        ];

        # Static IP reservations
        reservations = [
          {
            hw-address = "00:25:90:7a:b6:26";
            ip-address = "192.168.30.114";
            hostname = "zeeba";
          }
        ];
      }];
    };
  };

  # Make KEA wait for the network interface to be ready
  # This ensures enp2s0 is configured before KEA tries to bind to it
  systemd.services.kea-dhcp4-server = {
    after = [ "network-addresses-enp2s0.service" ];
    wants = [ "network-addresses-enp2s0.service" ];
    # Wait for the interface to be up and have an IP address
    serviceConfig.ExecStartPre = [
      (pkgs.writeShellScript "wait-for-enp2s0" ''
        set -e
        timeout=30
        count=0

        # Wait for interface to have link up and IP configured
        while [ $count -lt $timeout ]; do
          if ${pkgs.iproute2}/bin/ip link show enp2s0 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "LOWER_UP" && \
             ${pkgs.iproute2}/bin/ip addr show enp2s0 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "192.168.30.1"; then
            echo "enp2s0 is ready (link up, IP configured)"
            exit 0
          fi
          echo "Waiting for enp2s0 (link up and IP configured)... ($count/$timeout)"
          sleep 1
          count=$((count + 1))
        done

        echo "Timeout waiting for enp2s0 to be ready"
        ${pkgs.iproute2}/bin/ip link show enp2s0 2>&1 || echo "Interface not found"
        ${pkgs.iproute2}/bin/ip addr show enp2s0 2>&1 || echo "No IP address"
        exit 1
      '')
    ];
  };

  # Note: The nat.service is handled by the firewall service in NixOS.
  # No separate nat.service customization needed.

  # Ensure rp_filter stays disabled even after Tailscale starts
  # Tailscale tends to set rp_filter=2 which breaks NAT forwarding
  systemd.services.fix-rp-filter = {
    description = "Fix rp_filter after Tailscale";
    after = [ "tailscaled.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.procps}/bin/sysctl -w net.ipv4.conf.all.rp_filter=0 net.ipv4.conf.default.rp_filter=0 net.ipv4.conf.enp1s0.rp_filter=0 net.ipv4.conf.enp2s0.rp_filter=0 net.ipv4.conf.tailscale0.rp_filter=0 net.ipv4.conf.lo.rp_filter=0";
    };
  };


  networking = {
    # Tell NetworkManager to not manage the LAN interface (enp2s0)
    # so our static configuration can work properly
    networkmanager.unmanaged = [ "interface-name:enp2s0" ];

    # LAN – static network you control
    # Explicitly disable DHCP on the LAN interface since we're setting a static IP
    interfaces.enp2s0.useDHCP = false;
    interfaces.enp2s0.ipv4.addresses = [
      {
        address = "192.168.30.1";
        prefixLength = 24;
      }
    ];

    # Disable power saving on enp1s0 (WAN) interface to help prevent hardware hangs
    interfaces.enp1s0.wakeOnLan.enable = false;

    # NAT router - allows LAN clients to reach the internet via WAN (enp1s0)
    nat = {
      enable = true;
      externalInterface = "enp1s0";
      internalInterfaces = [ "enp2s0" ];
    };

    # Firewall with port forwarding
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 ]; # SSH and DNS for split-horizon
      allowedUDPPorts = [ 53 ]; # DNS for split-horizon
      trustedInterfaces = [ "enp2s0" ]; # Trust LAN interface
      
      # Disable reverse path filtering entirely
      # Both the sysctl AND iptables rpfilter can interfere with NAT
      # when Tailscale is running on the router
      checkReversePath = false;
    };

    # Port forwarding from external ports 80 and 443 to zeeba (192.168.30.114)
    nat.forwardPorts = [
      {
        sourcePort = 80;
        destination = "192.168.30.114:80";
        proto = "tcp";
      }
      {
        sourcePort = 443;
        destination = "192.168.30.114:443";
        proto = "tcp";
      }
    ];
  };

}
