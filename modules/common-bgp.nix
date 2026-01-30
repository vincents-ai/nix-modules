{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-bgp or { };

  bgpNeighborType = lib.types.submodule {
    options = {
      asn = lib.mkOption {
        type = lib.types.int;
        description = "Neighbor AS number";
      };

      address = lib.mkOption {
        type = lib.types.str;
        description = "Neighbor IP address";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Neighbor description";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "BGP MD5 password";
      };

      capabilities = lib.mkOption {
        type = lib.types.submodule {
          options = {
            multipath = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable multipath capability";
            };

            refresh = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable route refresh capability";
            };

            gracefulRestart = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable graceful restart";
            };
          };
        };
        default = { };
        description = "BGP capabilities";
      };

      timers = lib.mkOption {
        type = lib.types.submodule {
          options = {
            keepalive = lib.mkOption {
              type = lib.types.int;
              default = 60;
              description = "Keepalive timer in seconds";
            };

            hold = lib.mkOption {
              type = lib.types.int;
              default = 180;
              description = "Hold timer in seconds";
            };
          };
        };
        default = { };
        description = "BGP timers";
      };
    };
  };
in
{
  options.vincents-ai.common-bgp = with lib; {
    enable = mkEnableOption "FRR BGP Routing Configuration";

    asn = mkOption {
      type = types.int;
      description = "Local AS number";
    };

    routerId = mkOption {
      type = types.str;
      description = "BGP router ID (IPv4 address)";
    };

    neighbors = mkOption {
      type = types.attrsOf bgpNeighborType;
      default = { };
      description = "BGP neighbors configuration";
    };

    multipath = mkOption {
      type = types.bool;
      default = false;
      description = "Enable BGP multipath";
    };

    monitoring = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable BGP monitoring";
          };

          prometheus = mkOption {
            type = types.bool;
            default = false;
            description = "Export BGP metrics to Prometheus";
          };

          healthChecks = mkOption {
            type = types.bool;
            default = true;
            description = "Enable BGP health checks";
          };

          logLevel = mkOption {
            type = types.enum [
              "debugging"
              "informational"
              "notifications"
              "warnings"
              "errors"
            ];
            default = "informational";
            description = "BGP log level";
          };
        };
      };
      default = { };
      description = "BGP monitoring configuration";
    };

    ospf = mkOption {
      type = types.bool;
      default = false;
      description = "Enable OSPF routing";
    };

    bfd = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Bidirectional Forwarding Detection";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.optionals (cfg.asn != null) [
        {
          assertion = cfg.routerId != null;
          message = "BGP router ID must be specified when BGP is enabled";
        }
        {
          assertion =
            builtins.match "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$" cfg.routerId != null;
          message = "BGP router ID must be a valid IPv4 address";
        }
      ]
      ++ lib.mapAttrsToList (name: neighbor: {
        assertion = neighbor.asn != null && neighbor.address != null;
        message = "BGP neighbor ${name} must have ASN and address";
      }) cfg.neighbors;

    environment.etc."frr/frr.conf".text =
      let
        neighborConfig = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: neighbor: ''
            neighbor ${neighbor.address} remote-as ${toString neighbor.asn}
            ${lib.optionalString (neighbor.description != "") "  description ${neighbor.description}"}
            ${lib.optionalString (neighbor.password != null) "  password ${neighbor.password}"}
            ${lib.optionalString (neighbor.timers.keepalive != null) "  timers ${toString neighbor.timers.keepalive} ${toString (neighbor.timers.hold or 180)}"}
          '') cfg.neighbors
        );
      in
      ''
        router bgp ${toString cfg.asn}
        bgp router-id ${cfg.routerId}
        bgp log-neighbor-changes
        ${neighborConfig}
        ${lib.optionalString cfg.multipath "bgp bestpath as-path multipath"}
        ${lib.optionalString cfg.ospf "router ospf"}
        ${lib.optionalString cfg.bfd "bfd"}
        address-family ipv4 unicast
          ${lib.optionalString cfg.multipath "maximum-paths 64"}
        exit-address-family
      '';

    environment.etc."frr/daemons".text = ''
      bgpd=yes
      ${lib.optionalString cfg.ospf.enable "ospfd=yes"}
      ${lib.optionalString cfg.bfd.enable "bfdd=yes"}
      zebra=yes
      vtysh_enable=yes
      bgpd_options="-A 127.0.0.1 -M ${cfg.monitoring.logLevel or "informational"}"
      ${lib.optionalString cfg.ospf "ospfd_options=\"-A 127.0.0.1\""}
      ${lib.optionalString cfg.bfd "bfdd_options=\"-A 127.0.0.1\""}
      zebra_options="-A 127.0.0.1"
    '';

    systemd.services = {
      frr = {
        description = "FRRouting Daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.frr}/libexec/frr/frrinit.sh start";
          ExecStop = "${pkgs.frr}/libexec/frr/frrinit.sh stop";
          ExecReload = "${pkgs.frr}/libexec/frr/frrinit.sh reload";
          PIDFile = "/run/frr/frr.pid";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        path = [ pkgs.frr ];
      };
    };

  in
  lib.mkIf cfg.enable {
    let
      monitoringEnabled = cfg.monitoring.enable or false;
      healthChecksEnabled = cfg.monitoring.healthChecks or false;
    in
    lib.mkIf (monitoringEnabled && healthChecksEnabled) {
      systemd.services."vincentsai-bgp-health-check" = {
        description = "BGP Health Check Service";
        wantedBy = [ "multi-user.target" ];
        after = [ "frr.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "bgp-health-check" ''
            #!/bin/sh
            set -euo pipefail

            HEALTH_DIR="/run/vincentsai-health"
            mkdir -p "$HEALTH_DIR"

            if ! pgrep -f "bgpd" > /dev/null; then
              echo "unhealthy" > "$HEALTH_DIR/bgp.status"
              exit 1
            fi

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: neighbor: ''
                if ${pkgs.frr}/bin/vtysh -c "show bgp summary json" | jq -r ".ipv4Unicast.peers.\"${neighbor.address}\".state" | grep -q "Established"; then
                  : # Neighbor is established
                else
                  echo "unhealthy" > "$HEALTH_DIR/bgp.status"
                  exit 1
                fi
              '') cfg.neighbors
            )}

            echo "healthy" > "$HEALTH_DIR/bgp.status"
          '';
          TimeoutSec = "30s";
        };
      };

      systemd.timers."vincentsai-bgp-health-check" = {
        description = "BGP Health Check Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:*:0/30";
          Unit = "vincentsai-bgp-health-check.service";
        };
      };

      systemd.tmpfiles.rules = [
        "d /var/log/vincentsai 0755 root root -"
      ];
    };

    environment.systemPackages = with pkgs; [
      frr
      jq
    ];
  };
}
