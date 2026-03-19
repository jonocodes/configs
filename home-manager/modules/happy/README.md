# Happy Coder Module

Home-manager module for running Happy Coder daemon as a user systemd service.

## Files

- `happy-coder-daemon.nix` - Main module (use this)
- `happy-coder-daemon-example.nix` - Example configurations
- `HAPPY-CODER-SETUP.md` - Complete setup guide
- `HAPPY-QUICKSTART.md` - Quick reference
- `HAPPY-CODER-DECISION.md` - Why home-manager
- `HAPPY-CODER-COMPLETE-SUMMARY.md` - Complete overview
- `ZEEBA-HAPPY-DEPLOYMENT.md` - Zeeba deployment guide

## Usage

```nix
# In your home-manager config
{
  imports = [ ../modules/happy/happy-coder-daemon.nix ];

  services.happy-coder-daemon = {
    enable = true;
    # Uses pkgs.happy-coder from nixpkgs by default
  };
}
```

## Package Source

The module uses `pkgs.happy-coder` from nixpkgs by default.

Note: llm-agents.nix has happy-coder but no daemon support, so we use nixpkgs version.

## See Also

- For ccusage and other AI tools: Use llm-agents.nix input
- Example: See zeeba.nix for ccusage integration
