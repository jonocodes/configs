# Network Investigation - Ocarina Router

**Date:** 2026-01-29
**Status:** RESOLVED

## Summary

Two issues were identified and fixed on the router. A third issue was isolated to a specific client (zeeba).

| Issue | Root Cause | Status |
|-------|------------|--------|
| NAT forwarding broken | Tailscale rp_filter | Fixed |
| LAN jitter | Insufficient netdev_budget | Fixed |
| Zeeba high latency | Client-side (not router) | Not router issue |

---

## Issue 1: NAT Forwarding Broken

### Symptoms
- Router speedtest: 900+ Mbps
- Client speedtest through NAT: 2.38 Mbps

### Root Cause
Tailscale sets strict reverse path filtering (`rp_filter=2`) which blocks forwarded packets.

Two places enforce rp_filter:
1. **sysctl** `net.ipv4.conf.*.rp_filter`
2. **iptables** rpfilter module in mangle table

### Solution
```nix
boot.kernel.sysctl = {
  "net.ipv4.conf.all.rp_filter" = 0;
  "net.ipv4.conf.default.rp_filter" = 0;
  "net.ipv4.conf.enp1s0.rp_filter" = 0;
  "net.ipv4.conf.enp2s0.rp_filter" = 0;
  "net.ipv4.conf.tailscale0.rp_filter" = 0;
  "net.ipv4.conf.lo.rp_filter" = 0;
};

networking.firewall.checkReversePath = false;  # NOT "loose"
```

Plus systemd service to re-apply after Tailscale starts.

---

## Issue 2: LAN Jitter

### Symptoms
- Router → Client ping: 0.3ms consistent
- Client → Router ping: 0.7-13.7ms (asymmetric)

### Root Cause
- `rx_missed: 225` packets at NIC level
- `time_squeeze` events - softirq running out of budget

### Solution
```nix
boot.kernel.sysctl = {
  "net.core.netdev_budget" = 600;        # default 300
  "net.core.netdev_budget_usecs" = 4000; # default 2000
  "net.core.netdev_max_backlog" = 5000;  # default 1000
};
```

---

## Issue 3: Zeeba High Latency (NOT a router issue)

### Symptoms
- Lute → 1.1.1.1: 5.7-7.7ms (normal)
- Zeeba → 1.1.1.1: 3-30ms (high variance)

### Root Cause
**This is a zeeba client-side issue, not the router.**

Zeeba runs Tailscale and "offers exit node". Something on zeeba is causing latency spikes - likely Tailscale packet processing or rp_filter on zeeba itself.

### Evidence
The lute client through the same router shows only 2-3ms overhead:
```
Router direct:        3-4ms
Lute through router:  5.7-7.7ms  ✓ (only ~2-3ms NAT overhead)
Zeeba through router: 3-30ms    ✗ (zeeba-specific problem)
```

---

## Final Router Configuration

All changes in `router.nix`:

```nix
boot.kernel.sysctl = {
  "net.ipv4.conf.all.forwarding" = true;

  # Disable rp_filter (required for Tailscale + NAT)
  "net.ipv4.conf.all.rp_filter" = 0;
  "net.ipv4.conf.default.rp_filter" = 0;
  "net.ipv4.conf.enp1s0.rp_filter" = 0;
  "net.ipv4.conf.enp2s0.rp_filter" = 0;
  "net.ipv4.conf.tailscale0.rp_filter" = 0;
  "net.ipv4.conf.lo.rp_filter" = 0;

  # Network buffer tuning (reduces jitter)
  "net.core.netdev_budget" = 600;
  "net.core.netdev_budget_usecs" = 4000;
  "net.core.netdev_max_backlog" = 5000;
};

networking.firewall.checkReversePath = false;

# Re-apply rp_filter after Tailscale starts
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
```

---

## Final Performance (Router verified working)

| Metric | Before | After |
|--------|--------|-------|
| Router speedtest | 900 Mbps | 900 Mbps |
| Client NAT throughput (iperf3) | 2.38 Mbps | 308-414 Mbps |
| Client → Router LAN ping | 0.7-13.7ms | 0.9-2.8ms |
| Lute → Internet (through NAT) | N/A | 5.7-7.7ms ✓ |

---

## System Info

- **Host:** ocarina (NixOS 25.11)
- **WAN:** enp1s0 (RTL8168h, r8169 driver) - 1Gbps
- **LAN:** enp2s0 (RTL8125B, r8169 driver) - 1Gbps
- **Services:** Tailscale, NAT/masquerade, DHCP (kea), DNS (dnsmasq)

---

## Lessons Learned

1. **Tailscale + NAT router** requires `checkReversePath = false` (not "loose")
2. **Both sysctl AND iptables** rp_filter must be disabled
3. **Tailscale overrides sysctl** - need systemd service to reapply after it starts
4. **r8169 driver** benefits from increased `netdev_budget` for router workloads
5. **Test from multiple clients** to isolate client-specific vs router issues
6. **Use iperf3** for throughput testing, not speedtest-cli (which has server selection issues)

---

## TODO: Fix Zeeba

Zeeba needs its own investigation. Check:
- `sysctl net.ipv4.conf.all.rp_filter` on zeeba
- Tailscale exit node configuration
- Whether disabling Tailscale improves latency
