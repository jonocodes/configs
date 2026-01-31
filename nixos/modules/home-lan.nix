# Configuration for hosts on the home LAN (192.168.x.0/24) behind plex router
#
# Configures split-horizon DNS approach:
# - Prepends local router DNS (192.168.x.1) for internal domain resolution
# - DNS order: 192.168.x.1 (split-horizon) → 100.100.100.100 (Tailscale) → ISP (fallback)
# - Requires dnsmasq running on plex router
# - Causes cosmetic D-Bus timeout errors during nixos-rebuild switch (services work fine)
#
# Note: NAT hairpinning was attempted as alternative but broke general internet access.
# Split-horizon DNS is the cleaner, more reliable solution.
{ ... }:
{
  networking.networkmanager.insertNameservers = [ "192.168.30.1" ];
  
  # Tailscale search domain for short hostname resolution (e.g. "zeeba" → "zeeba.wolf-typhon.ts.net")
  networking.search = [ "wolf-typhon.ts.net" ];
}

