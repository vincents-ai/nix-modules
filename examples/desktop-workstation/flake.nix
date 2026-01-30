{
  description = "Desktop Workstation Example - Full desktop environment with audio and home manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-modules.url = "github:vincents-ai/vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, home-manager, nix-modules }: {
    nixosConfigurations = {
      desktop-workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          home-manager.nixosModules.default
          nix-modules.nixosModules.common
        ];
      };
    };

    homeConfigurations = {
      "shift@desktop-workstation" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs;
        modules = [
          ./home.nix
          nix-modules.nixosModules.common-home
        ];
      };
    };
  };
}
