# Nix Modules Examples

This directory contains example projects demonstrating how to use the `nix-modules`
repository for various NixOS configurations and Rust projects.

## Available Examples

### 1. Basic Server (`basic-server/`)

A minimal NixOS server configuration demonstrating:
- **common-monitoring.nix** - Prometheus, Grafana, Alertmanager stack
- **common-dns.nix** - Knot DNS and Kresd caching resolver
- **common-security.nix** - System hardening with firewall and fail2ban

**Quick start:**
```bash
cd basic-server
nix develop
nix build .#checks.x86_64-linux.vm-test
```

### 2. Rust Microservice (`rust-microservice/`)

A Rust service project demonstrating:
- **common-rust-service.nix** - Multi-architecture builds, UPX compression, SBOM generation
- **common-oci-builder.nix** - OCI image creation with SBOM embedding
- Kubernetes manifest generation

**Quick start:**
```bash
cd rust-microservice
nix develop
nix build .#package.x86_64-linux
nix build .#image-with-sbom
```

### 3. Desktop Workstation (`desktop-workstation/`)

A full desktop environment demonstrating:
- **common-desktop.nix** - GNOME or Hyprland with graphics drivers
- **common-audio.nix** - PipeWire/PulseAudio with Bluetooth support
- **common-home.nix** - Home Manager with shell, editor, and productivity tools

**Quick start:**
```bash
cd desktop-workstation
nix develop
nix build .#nixosConfigurations.desktop.config.system.build
```

### 4. BDD Test Setup (`bdd-test-setup/`)

A minimal project demonstrating BDD testing with:
- Gherkin feature files for natural language testing
- Python/pytest-bdd step definitions
- NixOS VM testing integration

**Quick start:**
```bash
cd bdd-test-setup
nix develop
nix build .#checks.x86_64-linux.vm-test
```

## Common Patterns

### Using nix-modules in Your Flake

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modules.url = "github:vincents-ai/vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, nix-modules }: {
    nixosConfigurations = {
      my-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          nix-modules.nixosModules.common
        ];
      };
    };
  };
}
```

### Enabling Modules

```nix
{ config, pkgs, ... }:

{
  imports = [ nix-modules.nixosModules.common ];

  # Enable monitoring
  vincents-ai.common-monitoring = {
    enable = true;
    prometheusPort = 9090;
  };

  # Enable security hardening
  vincents-ai.common-security = {
    enable = true;
    enableFirewall = true;
    enableFail2Ban = true;
  };
}
```

## Requirements

- Nix with flake support
- direnv (optional, for automatic environment loading)

## Resources

- [Nix Modules Documentation](../README.md)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Flakes Documentation](https://nixos.wiki/wiki/Flakes)
