# RFC: Centralized Nix Modules and BDD Testing Framework

**Status:** Accepted

## Summary

This RFC proposes the creation of a centralized repository for Nix modules to be shared across all `vincents-ai` projects. It also proposes the adoption of a Nix-based Behavior Driven Development (BDD) testing framework to standardize testing practices and improve code quality.

## Motivation

Currently, Nix configurations are scattered across multiple repositories, leading to duplication of effort and inconsistencies. A centralized repository for common modules will:

- **Reduce boilerplate:** Factor out common configurations into reusable modules.
- **Improve consistency:** Ensure all projects use the same versions of dependencies and configurations.
- **Simplify maintenance:** Update common modules in one place, rather than in each project.

The lack of a standardized testing framework has resulted in ad-hoc testing practices. A BDD testing framework will:

- **Improve collaboration:** Allow technical and non-technical stakeholders to understand and contribute to test scenarios.
- **Increase confidence:** Ensure that features meet business requirements.
- **Promote code quality:** Encourage developers to write testable code.

## Proposal

### Centralized Nix Modules

A new repository, `nix-modules`, will be created to house common Nix modules. This repository is structured as a Nix flake, allowing it to be easily imported into other projects.

The repository exposes the following modules:

- **common-dev-shell:** A comprehensive development shell for the vincents-ai platform, including tools for Kubernetes, containers, databases, and more.
- **rust-platform:** Utilities for Rust development, including toolchain management and build input helpers.
- **common-rust-package:** A helper function to create Rust package derivations with standard configurations.
- **common-monitoring:** A self-contained monitoring stack including Prometheus, Grafana, and Alertmanager.
- **common-dns:** A DNS service module using Knot DNS and Kresd, configurable via options.
- **common-oci-builder:** Utilities for building OCI container images.

### BDD Testing Framework

A Nix-based BDD testing framework is implemented in the `nix-modules/testing` directory. This framework is based on the NixOS test framework and uses `pytest-bdd` to run Gherkin feature files.

The framework provides a bridge between the NixOS test driver and the BDD test context, allowing step definitions to interact with the virtual machines managed by the test driver.

## Implementation Plan

1. **Create the `nix-modules` repository:** Created a new Git repository and initialized it with a `flake.nix` file.
2. **Implement the BDD testing framework:** Added the BDD testing framework to the `nix-modules` repository.
3. **Extract common modules:** Identified and extracted common Nix modules from the existing codebases.
4. **Integrate `nix-modules` into existing projects:** Update the `flake.nix` files of the existing projects to import the `nix-modules` flake.

## Usage

### Using Common Modules

To use the common modules in your project, add this flake as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modules.url = "github:vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, nix-modules }:
    nix-modules.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        nixosModules = [
          nix-modules.nixosModules.common-monitoring
        ];

        devShells.default = pkgs.mkShell {
           # ... use pkgs from nixpkgs ...
        };
      });
}
```

Then, import the module in your NixOS configuration:

```nix
{ config, pkgs, ... }:
{
  imports = [
    nix-modules.nixosModules.common-monitoring
  ];

  services.prometheus.enable = true;
}
```

### Using the BDD Framework

To use the BDD testing framework, include the test in your project's checks:

```nix
checks.x86_64-linux.bdd-test = import nix-modules.checks.bdd-vm-test;
```

## Future Work

- Extract more common modules from the codebase.
- Add documentation for each module.
- Create more BDD test examples.
