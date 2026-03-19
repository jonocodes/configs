# Adding llm-agents.nix for ccusage

## What We're Doing

Adding ccusage (Claude Code usage tracker) from llm-agents.nix to zeeba.

## Steps

### 1. Add llm-agents to flake.nix

```nix
# In home-manager/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Add llm-agents
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, nixpkgs, home-manager, llm-agents, ... }: {
    homeConfigurations = {
      zeeba = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };

        # Pass llm-agents to modules
        extraSpecialArgs = { inputs = { inherit llm-agents; }; };

        modules = [ ./hosts/zeeba.nix ];
      };
    };
  };
}
```

### 2. Already Done in zeeba.nix

The zeeba config already has ccusage conditionally added:

```nix
home.packages = with pkgs-unstable;
  [
    # ... other packages ...
  ] ++ (with pkgs; [
    # AI coding tools from llm-agents.nix
    (if inputs ? llm-agents then inputs.llm-agents.packages.${pkgs.system}.ccusage else null)
  ]);
```

This means:
- If llm-agents input exists: Use ccusage
- If not: Skip it (no error)

### 3. Deploy

```bash
cd /home/jono/sync/configs/home-manager
home-manager switch --flake .#zeeba
```

### 4. Verify

```bash
ssh zeeba
which ccusage
ccusage --help
```

## What is ccusage?

From llm-agents.nix:
- **ccusage** - Track Claude Code usage and costs
- Helps monitor API usage
- Useful for cost tracking

## Alternative: Don't Add Flake Input

If you don't want to add llm-agents to your flake, you can:

```nix
# Direct install (less efficient)
home.packages = [
  (builtins.getFlake "github:numtide/llm-agents.nix").packages.${pkgs.system}.ccusage
];
```

Or just install it standalone:

```bash
nix profile install github:numtide/llm-agents.nix#ccusage
```

## Binary Cache (Optional)

Add Numtide's binary cache for faster downloads:

```nix
# In NixOS config
nix.settings = {
  substituters = [ "https://numtide.cachix.org" ];
  trusted-public-keys = [
    "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
  ];
};
```

## Status

✅ zeeba.nix updated to use ccusage (conditional)
⬜ flake.nix needs llm-agents input added
⬜ Deploy to test

## Other Tools Available in llm-agents.nix

- aider-chat
- claude-code
- continue
- goose
- cursor
- And many more AI coding tools

See: https://github.com/numtide/llm-agents.nix
