# Rust Microservice Example

This example demonstrates how to build a Rust microservice with multi-architecture
support and OCI image creation using the `nix-modules` repository.

Key features:
- Multi-architecture builds (x86_64-linux, aarch64-linux)
- UPX binary compression with performance measurements
- SPDX SBOM generation
- OCI image building with embedded SBOM
- Kubernetes manifest generation

## Usage

1. Enter the development shell:
   ```bash
   cd examples/rust-microservice
   nix develop
   ```

2. Build the service for your current platform:
   ```bash
   nix build .#package.x86_64-linux
   ```

3. Build multi-architecture images:
   ```bash
   nix build .#images
   ```

4. Build OCI image with SBOM:
   ```bash
   nix build .#image-with-sbom
   ```

5. Generate Kubernetes manifests:
   ```bash
   nix build .#kubernetes-manifests
   ```

## Project Structure

```
rust-microservice/
├── Cargo.toml          # Rust project manifest
├── Cargo.lock          # Locked dependencies
├── src/
│   └── main.rs         # Application source
├── flake.nix           # Nix flake configuration
└── README.md           # This file
```

## Building for Multiple Platforms

The example is configured to build for:
- x86_64-linux
- aarch64-linux

To add more platforms, update the `supportedSystems` in `flake.nix`.

## OCI Image Details

The OCI image includes:
- UPX-compressed binary
- SBOM in SPDX JSON format
- Labels for OCI metadata
- Minimal runtime dependencies

## Kubernetes Deployment

The generated manifests include:
- Namespace configuration
- Deployment with resource limits
- Service definition
- gRPC health probes
- Network policy (basic)
