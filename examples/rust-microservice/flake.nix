{
  description = "Rust Microservice Example - Multi-arch build with OCI images";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    rust-overlay.url = "github:oxalica/rust-overlay";
    nix-modules.url = "github:vincents-ai/vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, crane, rust-overlay, nix-modules }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        craneLib = crane.mkLib (import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        });
      });

      rustService = nix-modules.nixosModulesCommon.common-rust-service;
    in
    {
      packages = forAllSystems ({ pkgs, craneLib }: let
        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src;
          pname = "rust-microservice";
          version = "0.1.0";
          nativeBuildInputs = [ pkgs.pkg-config pkgs.protobuf ];
          buildInputs = [ pkgs.openssl pkgs.pcsclite ];
        };
      in {
        package = craneLib.buildPackage commonArgs;

        image-with-sbom = rustService.buildOciImageWithSbom {
          inherit (commonArgs) pname;
          binary = craneLib.buildPackage commonArgs;
          includeSbom = true;
          extraLabels = {
            "org.opencontainers.image.title" = "Rust Microservice Example";
          };
        };
      });

      images = forAllSystems ({ pkgs, craneLib }: let
        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src;
          pname = "rust-microservice";
          version = "0.1.0";
          nativeBuildInputs = [ pkgs.pkg-config pkgs.protobuf ];
          buildInputs = [ pkgs.openssl pkgs.pcsclite ];
        };
      in rustService.buildOciImageWithSbom {
        inherit (commonArgs) pname;
        binary = craneLib.buildPackage commonArgs;
        includeSbom = true;
      });

      kubernetes-manifests = rustService.buildKubernetesManifests {
        namespace = "rust-microservice";
        services = {
          rust-microservice = {
            image = "vincents-ai/rust-microservice:0.1.0";
            port = 8080;
            profiles = {
              small = {};
              medium = {};
              large = {};
            };
          };
        };
        commonEnv = {
          RUST_LOG = "info";
          RUST_BACKTRACE = "1";
        };
      };

      devShells.default = forAllSystems ({ pkgs }: pkgs.mkShell {
        packages = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          cargo-audit
          cargo-outdated
        ];
      });
    };
}
