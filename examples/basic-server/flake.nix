{
  description = "Basic Server Example - NixOS configuration with monitoring, DNS, and security";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modules.url = "github:vincents-ai/vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, nix-modules }: {
    nixosConfigurations = {
      basic-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          nix-modules.nixosModules.common
        ];
      };
    };

    checks.x86_64-linux.vm-test = import ./test-vm.nix {
      inherit (nixpkgs) lib;
      nix-modules = nix-modules;
      pkgs = nixpkgs;
    };
  };
}
