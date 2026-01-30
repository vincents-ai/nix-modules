# Basic Server Example

This example demonstrates how to create a minimal NixOS server configuration using
the `nix-modules` repository. It showcases three key modules:

- `common-monitoring.nix` - Prometheus, Grafana, and Alertmanager for observability
- `common-dns.nix` - Knot DNS and Kresd for local DNS resolution
- `common-security.nix` - System hardening with firewall and intrusion prevention

## Usage

1. Enter the development shell:
   ```bash
   cd examples/basic-server
   nix develop
   ```

2. Build the VM test to verify the configuration:
   ```bash
   nix build .#checks.x86_64-linux.vm-test
   ```

3. Deploy to a real NixOS machine:
   ```bash
   sudo nixos-rebuild switch --flake .#basic-server
   ```

## Configuration Overview

### Monitoring Stack
The monitoring module enables:
- Prometheus on port 9090
- Node Exporter on port 9100
- Alertmanager on port 9093
- Grafana on port 3000 (admin/admin)

### DNS Services
The DNS module provides:
- Knot DNS as the authoritative server
- Kresd as the caching resolver
- DNS query logging and metrics

### Security Hardening
The security module applies:
- nftables firewall with default deny policy
- fail2ban for intrusion prevention
- sysctl hardening (kptr_restrict, dmesg_restrict)
- Core dump disabled by default

## Files

- `flake.nix` - Flake configuration and module imports
- `configuration.nix` - NixOS system configuration
- `README.md` - This file
