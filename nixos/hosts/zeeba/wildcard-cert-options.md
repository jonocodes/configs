# Wildcard Certificate Options for *.savr.dgt.is

## The Problem

Caddy needs a wildcard certificate for `*.savr.dgt.is` (for Coolify preview branches). Wildcard certificates require DNS-01 challenge validation, which means Caddy needs API access to modify DNS records.

Namecheap's API requires IP whitelisting, which doesn't work with a dynamic IP.

## Solution: Subdomain Delegation

Delegate just `savr.dgt.is` to a DNS provider with a proper API. All other `dgt.is` records stay in Namecheap.

In Namecheap, add NS records:
```
savr   NS   <provider-ns1>
savr   NS   <provider-ns2>
```

Then manage `savr.dgt.is` and `*.savr.dgt.is` in the delegated provider.

## Provider Comparison

| | Cloudflare | deSEC | Hurricane Electric |
|---|---|---|---|
| **Reliability** | Excellent (huge infrastructure) | Good (smaller but focused) | Excellent (major network provider) |
| **Caddy plugin** | Most popular, well-maintained | Well-maintained | Well-maintained |
| **UI/Dashboard** | Modern, polished | Simple, functional | Dated but works |
| **DDNS support** | Via API | Built-in | Via API |
| **Privacy** | Large corp, some concerns | Non-profit, privacy-focused | Neutral |
| **Setup complexity** | Easy | Easy | Easy |
| **Cost** | Free | Free | Free |

### Cloudflare
- **Nameservers:** Provided when you add the domain
- **Caddy plugin:** `github.com/caddy-dns/cloudflare`
- **Pros:** Most reliable, best plugin support, excellent UI
- **Cons:** Privacy concerns if that matters to you

I think this requires eithere CF to control the apex domain, or to use cloudflare tunnel, which I never figured out.

### deSEC (desec.io)
- **Nameservers:** `ns1.desec.io`, `ns2.desec.org`
- **Caddy plugin:** `github.com/caddy-dns/desec`
- **Pros:** Privacy-focused, non-profit, built for DDNS + ACME use case
- **Cons:** Smaller service

Can only host a single domain. Guess I can create multiple accounts.

### Hurricane Electric (dns.he.net)
- **Nameservers:** Provided when you add the domain
- **Caddy plugin:** `github.com/caddy-dns/he`
- **Pros:** Very established, been around forever, reliable
- **Cons:** Dated UI

Does not jive with cpanel in the main domain, so need to bring my own domain, but it cant be a subdomain it seems since cpanel wont allow NS for subdomains

## NixOS Caddy Configuration Example

```nix
services.caddy = {
  enable = true;

  # Build Caddy with DNS plugin (example for Cloudflare)
  package = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@latest" ];
    hash = "sha256-XXXXX";  # Calculate with: nix-prefetch-url --unpack <url>
  };

  globalConfig = ''
    acme_dns cloudflare {env.CF_API_TOKEN}
  '';

  virtualHosts."*.savr.dgt.is".extraConfig = ''
    reverse_proxy localhost:82
  '';
};

# Set API token for Caddy service
systemd.services.caddy.environment = {
  CF_API_TOKEN = "your-api-token";  # Or read from file
};
```

## Recommendation

- **Cloudflare** if you want maximum reliability and don't mind using them
- **deSEC** if you prefer privacy-focused/non-profit
- **Hurricane Electric** if you want something established but low-profile

All three are free and work well for this use case.
