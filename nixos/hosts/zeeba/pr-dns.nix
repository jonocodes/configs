{ pkgs, ... }:

# Wildcard DNS for Coolify PR previews
# Resolves *.pr.zeeba → zeeba's Tailscale IP
#
# After deploying, configure Tailscale split DNS in admin console:
# 1. Go to https://login.tailscale.com/admin/dns
# 2. Add nameserver: 100.114.234.110 for domain "pr.zeeba"
# 3. Enable "Override local DNS" for this nameserver

let
  dnsmasqConf = pkgs.writeText "dnsmasq-pr.conf" ''
    # Only listen on Tailscale IP - NOT localhost
    listen-address=100.114.234.110
    bind-interfaces

    # Don't read /etc/resolv.conf or act as general resolver
    no-resolv
    no-hosts

    # Wildcard: *.pr.zeeba → zeeba's Tailscale IP
    # This matches pr.zeeba and anything.pr.zeeba
    address=/pr.zeeba/100.114.234.110

    # Logging for debug
    log-queries
  '';
in
{
  # Custom systemd service - bypasses NixOS dnsmasq module entirely
  systemd.services.dnsmasq-pr = {
    description = "dnsmasq for PR preview wildcard DNS";
    after = [ "network.target" "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";  # Wait for tailscale0
      ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq -k -C ${dnsmasqConf}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Open DNS port on Tailscale interface only
  networking.firewall.interfaces."tailscale0" = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
}
