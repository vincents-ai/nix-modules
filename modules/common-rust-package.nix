# nix-modules/modules/common-rust-package.nix
{ pkgs, ... }:

{
  options.vincents-ai.common-rust-package = {
    enable = pkgs.lib.mkEnableOption "Common Rust package builder";

    # Function to create a rust package derivation
    mkRustPackage = pkgs.lib.mkOption {
      type = pkgs.lib.types.raw;
      description = "Function to create a Rust package derivation";
    };
  };

  config = pkgs.lib.mkIf config.vincents-ai.common-rust-package.enable {
    vincents-ai.common-rust-package = {
      mkRustPackage = { pname, version, src, cargoLock ? null, nativeBuildInputs ? [ ], buildInputs ? [ ], ... } @ args:
        let
          # Default environment configuration for OpenSSL
          envConfig = {
            OPENSSL_DIR = "${pkgs.openssl.dev}";
            OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
            PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          };
        in
        pkgs.rustPlatform.buildRustPackage (args // {
          inherit pname version src;
          nativeBuildInputs = nativeBuildInputs ++ [ pkgs.pkg-config ];
          buildInputs = buildInputs ++ [ pkgs.openssl ];
        } // envConfig);
    };
  };
}
