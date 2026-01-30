# nix-modules

This repository contains centralized Nix modules and a Behavior Driven Development (BDD) testing framework for the `vincents-ai` projects.

## Available Modules

| Module | Purpose |
|--------|---------|
| `common-rust-service` | Common patterns for Rust services: build inputs, OCI images, environment-specific builds, dev shells |
| `common-rust-package` | Rust package building utilities |
| `common-dev-shell` | Development shell configuration |
| `common-dns` | DNS configuration for services (Knot DNS + Kresd with TSIG keys and dnstap) |
| `common-dhcp` | Kea DHCP server configuration with DDNS integration |
| `common-bgp` | FRR BGP routing configuration |
| `common-policy-routing` | Policy-based routing with iproute2 and nftables |
| `common-monitoring` | Monitoring and observability setup (Prometheus + Grafana + Alertmanager) |
| `common-secrets` | Secrets management patterns with health checks |
| `common-certificates` | Certificate management with ACME and rotation support |
| `common-log-aggregation` | Log aggregation framework (Fluent Bit) |
| `common-health-monitoring` | Comprehensive health monitoring framework with alerts and recovery |
| `common-troubleshooting` | Troubleshooting decision trees and diagnostic utilities |
| `common-oci-builder` | OCI container image building utilities |
| `rust-platform` | Rust platform utilities |

## Library Functions

The `lib/` directory contains reusable utility functions:

| Library | Purpose |
|---------|---------|
| `lib/validators.nix` | Validation functions for IP addresses, CIDR, MAC addresses, ports, etc. |
| `lib/health-checks.nix` | Health check types, validation, and script generation utilities |

## Usage

To use the common modules in your project, add this flake as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-modules.url = "github:vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, flake-utils, nix-modules }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        modules = import ./modules;
      in
      {
        nixosModules = [ modules ];
      });
}
```

Then import the modules in your NixOS configuration:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    # Import the common modules
    (nix-modules + "/modules/default.nix")
  ];

  # Enable and configure DNS
  vincents-ai.common-dns.enable = true;
  vincents-ai.common-dns.domain = "example.com";
  vincents-ai.common-dns.gatewayIpv4 = "192.168.1.1";

  # Enable DHCP
  vincents-ai.common-dhcp.enable = true;
  vincents-ai.common-dhcp.lanInterface = "eth0";

  # Enable monitoring
  vincents-ai.common-monitoring.enable = true;
  vincents-ai.common-monitoring.grafanaEnable = true;

  # Enable health monitoring
  vincents-ai.common-health-monitoring.enable = true;
  vincents-ai.common-health-monitoring.components = {
    network = {
      enable = true;
      checks = [
        { type = "connectivity"; target = "8.8.8.8"; protocol = "icmp"; }
      ];
    };
  };
}
```

## BDD Testing Framework

This repository also provides a Nix-based BDD testing framework. To use it, you can run the tests defined in the `testing` directory:

```bash
nix build .#checks.x86_64-linux.bdd-vm-test
```

## Contributing

Please see the [RFC](docs/rfc/0001-centralized-nix-modules-and-bdd-testing.md) for more information on the motivation and design of this repository.
