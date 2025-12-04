# Triplit JWT Secret Setup

This document explains how to set up the JWT secret for the Triplit container without storing it in git.

## Overview

The Triplit container configuration in `web.nix` now reads a JWT secret from `/etc/triplit-jwt-secret`. This approach keeps the secret out of your git repository while still making it available to the container.

## Setup Instructions

1. **Create the secret file on the target machine:**
   ```bash
   sudo mkdir -p /etc
   sudo touch /etc/triplit-jwt-secret
   sudo chmod 600 /etc/triplit-jwt-secret
   ```

2. **Add your JWT secret to the file:**
   ```bash
   sudo nano /etc/triplit-jwt-secret
   # Add your JWT secret value here and save the file
   ```

3. **Verify the file permissions:**
   ```bash
   ls -la /etc/triplit-jwt-secret
   # Should show: -rw------- 1 root root ...
   ```

4. **Rebuild your NixOS configuration:**
   ```bash
   sudo nixos-rebuild switch
   ```

## How It Works

The secret is read from `/etc/triplit-jwt-secret` and made available to the Triplit container as the `TRIPLIT_JWT_SECRET` environment variable. This secret is used by Triplit for JWT token signing and verification.

## Important Notes

- The secret file `/etc/triplit-jwt-secret` should **NOT** be tracked in git
- The file has restrictive permissions (600) to prevent unauthorized access
- The secret is read during NixOS evaluation and embedded in the container environment
- If you need to change the secret, modify the file and rebuild your configuration

## Alternative Approaches

For more robust secret management, consider:

1. **SOPS (Secrets OPerationS)** - Already commented out in your configuration
2. **agenix** - Age-based encryption for NixOS secrets
3. **Docker secrets** - If using Docker Swarm mode
4. **Kubernetes secrets** - If running in Kubernetes

These alternatives provide better security for production environments.