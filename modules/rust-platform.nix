# nix-modules/modules/rust-platform.nix
{ pkgs, ... }:

let
  inherit (pkgs) lib;
in
{
  options.vincents-ai.rust-platform = {
    enable = lib.mkEnableOption "Rust platform utilities";
  };

  config = lib.mkIf config.vincents-ai.rust-platform.enable {
    vincents-ai.rust-lib = {
      getToolchain = toolchainPkgs: toolchainPkgs.rust-bin.stable.latest.default.override {
        extensions = [ "rust-src" "rust-analyzer" ];
      };

      getBuildInputs = toolchainPkgs: with toolchainPkgs; [
        pkg-config
        openssl
        openssl.dev
      ];

      mkDevShell = toolchainPkgs: { packages ? [ ], ... } @ args:
        toolchainPkgs.mkShell (args // {
          buildInputs = (args.buildInputs or [ ]) ++ [
            (toolchainPkgs.rust-bin.stable.latest.default.override {
              extensions = [ "rust-src" "rust-analyzer" ];
            })
          ] ++ with toolchainPkgs; [
            pkg-config
            openssl
            openssl.dev
          ] ++ packages;
        });
    };
  };
}
