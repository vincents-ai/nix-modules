{ lib }:

let
  healthCheckType = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.str;
        description = "Health check type";
      };

      target = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Check target";
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Port to check";
      };

      protocol = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Protocol (tcp, udp, icmp)";
      };

      expectedState = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Expected state";
      };

      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Timeout for check";
      };

      retries = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Number of retries";
      };
    };
  };
in
{
  inherit healthCheckType;
}
