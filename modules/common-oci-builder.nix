# nix-modules/modules/common-oci-builder.nix
{ pkgs, lib, ... }:

let
  cfg = config.vincents-ai.common-oci-builder or { };
in
{
  options.vincents-ai.common-oci-builder = with lib; {
    enable = mkEnableOption "Common OCI Image Builder Utilities";

    mkOciImage = mkOption {
      type = types.raw;
      description = "Function to create an OCI image derivation";
    };
  };

  config = lib.mkIf cfg.enable {
    vincents-ai.common-oci-builder = {
      mkOciImage = { name, tag ? "latest", contents ? [ ], config ? { }, ... } @ args:
        pkgs.dockerTools.buildImage {
          inherit name tag;
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = contents;
          };
          inherit config;
        };
    };
  };
}
