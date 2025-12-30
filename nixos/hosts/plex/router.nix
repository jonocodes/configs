{ pkgs, config, ... }:
{

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    # enable if you also want IPv6 routing:
    # "net.ipv6.conf.all.forwarding" = true;
  };

  # Fix e1000e hardware unit hang on eno1 (WAN interface)
  # Disable power management, adjust interrupt moderation, and disable offloading
  boot.kernelParams = [
    "e1000e.InterruptThrottleRate=1"  # Disable interrupt throttling (1 = off)
  ];

  # Disable power management and offloading for e1000e interface to prevent hardware hangs
  services.udev.extraRules = ''
    # Disable power management for e1000e (eno1) to prevent hardware unit hangs
    ACTION=="add", SUBSYSTEM=="net", DRIVERS=="e1000e", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="eno1", RUN+="${pkgs.bash}/bin/bash -c 'echo 0 > /sys/class/net/%k/device/power/autosuspend_delay_ms 2>/dev/null || true'"
    
    # Disable offloading features that can cause hardware hangs
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="eno1", RUN+="${pkgs.ethtool}/bin/ethtool -K %k tso off gso off gro off lro off 2>/dev/null || true"
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="eno1", RUN+="${pkgs.ethtool}/bin/ethtool -A %k autoneg off rx off tx off 2>/dev/null || true"
  '';

  # Install ethtool for udev rules
  environment.systemPackages = with pkgs; [
    ethtool
  ];

  services.duckdns = {
    enable = true;
    domains = [ "digitus" ];
    tokenFile = "/etc/duckdns.token";
  };

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "enp1s0" ];  # your LAN NIC
      };

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      subnet4 = [{
        id = 1;
        subnet = "192.168.200.0/24";

        pools = [{
          pool = "192.168.200.100 - 192.168.200.200";
        }];

        option-data = [
          {
            name = "routers";
            data = "192.168.200.1";  # router IP on LAN
          }
          # {
          #   name = "domain-name-servers";
          #   # KEA expects comma-separated IP addresses for domain-name-servers
          #   data = "1.1.1.1,8.8.8.8";
          # }
        ];

        # Static IP reservations
        reservations = [
          {
            hw-address = "00:25:90:7a:b6:26";
            ip-address = "192.168.200.114";
            hostname = "zeeba";
          }
        ];
      }];
    };
  };

  # Make KEA wait for the network interface to be ready
  # This ensures enp1s0 is configured before KEA tries to bind to it
  systemd.services.kea-dhcp4-server = {
    after = [ "network-online.target" "network.target" ];
    wants = [ "network-online.target" ];
    # Wait for the interface to be up and have an IP address
    # Check for LOWER_UP (link is up) and the IP address, with a timeout
    # Use iproute2 package to ensure ip command is available
    serviceConfig.ExecStartPre = [
      (pkgs.writeShellScript "wait-for-enp1s0" ''
        set -e
        export PATH="${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:$PATH"
        timeout=30
        count=0
        
        # Wait for interface to exist and be UP with link
        while [ $count -lt $timeout ]; do
          if ${pkgs.iproute2}/bin/ip link show enp1s0 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "LOWER_UP" && \
             ${pkgs.iproute2}/bin/ip addr show enp1s0 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "192.168.200.1"; then
            echo "enp1s0 is ready (link up, IP configured)"
            exit 0
          fi
          echo "Waiting for enp1s0 (link up and IP configured)... ($count/$timeout)"
          ${pkgs.coreutils}/bin/sleep 1
          count=$((count + 1))
        done
        
        echo "Timeout waiting for enp1s0 to be ready"
        echo "Current state:"
        ${pkgs.iproute2}/bin/ip link show enp1s0 2>&1 || echo "Interface not found"
        ${pkgs.iproute2}/bin/ip addr show enp1s0 2>&1 || echo "No IP address"
        exit 1
      '')
    ];
  };

  # Ensure NAT service starts after network is ready
  systemd.services.nat = {
    after = [ "network-online.target" "network.target" ];
    wants = [ "network-online.target" ];
  };

  # Apply e1000e fixes after network interface is up
  # This ensures offloading is disabled even if udev rules don't catch it
  # this fix was created since running a speed test from a client connected to the LAN port would cause the WAN port to hang with an error: "e1000e ... eno1: Detected Hardware Unit Hang"
  systemd.services.fix-e1000e = {
    description = "Fix e1000e hardware hang issues";
    after = [ "network-online.target" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for eno1 to be up
      for i in {1..30}; do
        if ${pkgs.iproute2}/bin/ip link show eno1 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "state UP"; then
          break
        fi
        sleep 1
      done
      
      # Disable offloading features
      ${pkgs.ethtool}/bin/ethtool -K eno1 tso off gso off gro off lro off 2>/dev/null || true
      ${pkgs.ethtool}/bin/ethtool -A eno1 autoneg off rx off tx off 2>/dev/null || true
      
      # Disable power management
      echo 0 > /sys/class/net/eno1/device/power/autosuspend_delay_ms 2>/dev/null || true
      echo "on" > /sys/class/net/eno1/device/power/control 2>/dev/null || true
    '';
  };



  networking = {
    # Tell NetworkManager to not manage the LAN interface (enp1s0)
    # so our static configuration can work properly
    networkmanager.unmanaged = [ "interface-name:enp1s0" ];

    # LAN – static network you control
    # Explicitly disable DHCP on the LAN interface since we're setting a static IP
    interfaces.enp1s0.useDHCP = false;
    interfaces.enp1s0.ipv4.addresses = [
      {
        address = "192.168.200.1";
        prefixLength = 24;
      }
    ];

    # Disable power saving on eno1 (WAN) interface to help prevent hardware hangs
    interfaces.eno1.wakeOnLan.enable = false;

    # NAT router - allows LAN clients to reach the internet via WAN (eno1)
    nat = {
      enable = true;
      externalInterface = "eno1";
      internalInterfaces = [ "enp1s0" ];
    };

    # Firewall with port forwarding
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]; # SSH to router only
      trustedInterfaces = [ "enp1s0" ]; # Trust LAN interface
      
      # The checkReversePath option can interfere with NAT
      # Setting to "loose" allows forwarded packets through
      checkReversePath = "loose";
    };

    # Port forwarding from external ports 80 and 443 to zeeba (192.168.200.114)
    nat.forwardPorts = [
      {
        sourcePort = 80;
        destination = "192.168.200.114:80";
        proto = "tcp";
      }
      {
        sourcePort = 443;
        destination = "192.168.200.114:443";
        proto = "tcp";
      }
    ];
  };

}
