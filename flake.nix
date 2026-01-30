{
  description = "Centralized Nix modules for vincents-ai projects";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, crane, rust-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.foldl' (acc: system: acc // { ${system} = f system; }) {} systems;
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = import ./modules;
    in
    {
      nixosModules = modules;

      checks = forAllSystems (system: {
        bdd-vm-test = import ./testing/flake.nix { inherit system nixpkgs; };
      });

      devShells = forAllSystems (system: let
        systemPkgs = import nixpkgs { inherit system; };
      in {
        default = systemPkgs.mkShell {
          packages = with systemPkgs; [
            nix
          ];
        };
      });

      formatter = forAllSystems (system: let
        systemPkgs = import nixpkgs { inherit system; };
      in systemPkgs.nixfmt);
    };
}
