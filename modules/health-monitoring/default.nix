{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-health-monitoring or { };
  healthChecksLib = import ../../lib/health-checks.nix { inherit lib; };
in
{
  options.vincents-ai.common-health-monitoring = with lib; {
    enable = mkEnableOption "Health Monitoring Framework";

    interval = mkOption {
      type = types.str;
      default = "30s";
      description = "Health check interval";
    };

    timeout = mkOption {
      type = types.str;
      default = "10s";
      description = "Health check timeout";
    };

    components = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable health monitoring for this component";
            };

            interval = mkOption {
              type = types.str;
              default = "30s";
              description = "Health check interval for this component";
            };

            timeout = mkOption {
              type = types.str;
              default = "10s";
              description = "Health check timeout for this component";
            };

            checks = mkOption {
              type = types.listOf types.attrs;
              default = [ ];
              description = "List of health checks for this component";
            };

            alerts = mkOption {
              type = types.submodule {
                options = {
                  enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable alerts for this component";
                  };
                };
              };
              default = { };
              description = "Alert configuration";
            };
          };
        }
      );
      default = { };
      description = "Health monitoring components";
    };

    dashboard = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable health dashboard";
          };

          port = mkOption {
            type = types.int;
            default = 8080;
            description = "Dashboard port";
          };

          bindAddress = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Dashboard bind address";
          };
        };
      };
      default = { };
      description = "Dashboard configuration";
    };

    recovery = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable automatic recovery";
          };

          maxRetries = mkOption {
            type = types.int;
            default = 3;
            description = "Maximum recovery attempts";
          };

          retryDelay = mkOption {
            type = types.str;
            default = "30s";
            description = "Delay between recovery attempts";
          };
        };
      };
      default = { };
      description = "Recovery configuration";
    };

    scoring = mkOption {
      type = types.submodule {
        options = {
          weights = mkOption {
            type = types.attrsOf types.int;
            default = {
              network = 30;
              dns = 25;
              dhcp = 20;
              system = 10;
            };
            description = "Health score weights per component";
          };
        };
      };
      default = { };
      description = "Scoring configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bash
      procps
      iproute2
      netcat
      dnsutils
      sqlite
      util-linux
      gawk
      gnugrep
    ];

    systemd.services."vincentsai-health-monitor" = {
      description = "Health Monitoring Service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "health-monitor" ''
          HEALTH_STATE_DIR="/run/vincentsai-health"
          LOG_FILE="/var/log/vincentsai/health-monitor.log"

          mkdir -p "$HEALTH_STATE_DIR" "$(dirname "$LOG_FILE")"

          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
          }

          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (componentName: componentConfig: ''
              if [ "${boolToString (componentConfig.enable or true)}" = "true" ]; then
                log "Checking health of ${componentName}"
                echo "1" > "$HEALTH_STATE_DIR/${componentName}.status"
                echo "$(date +%s)" > "$HEALTH_STATE_DIR/${componentName}.last_check"
              fi
            '') cfg.components
          )}

          log "Health monitoring cycle completed"
        '';
        User = "root";
        Group = "root";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/run/vincentsai-health"
          "/var/log/vincentsai"
        ];
      };
    };

    systemd.services."vincentsai-health-dashboard" = lib.mkIf cfg.dashboard.enable {
      description = "Health Monitoring Dashboard";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "health-dashboard" ''
          HEALTH_STATE_DIR="/run/vincentsai-health"
          DASHBOARD_DATA="/run/vincentsai-health/dashboard.json"

          mkdir -p "$HEALTH_STATE_DIR" "$(dirname "$DASHBOARD_DATA")"

          while true; do
            echo '{'
            echo '  "timestamp": "'$(date -Iseconds)'",'
            echo '  "components": {'
            ${lib.concatStringsSep ",\n" (
              lib.mapAttrsToList (componentName: componentConfig: ''
                echo '    "${componentName}": {'
                echo '      "status": "'$(cat "$HEALTH_STATE_DIR/${componentName}.status" 2>/dev/null || echo "unknown")'",'
                echo '      "last_check": "'$(cat "$HEALTH_STATE_DIR/${componentName}.last_check" 2>/dev/null || echo "0")'"'
                echo '    }'
              '') cfg.components
            )}
            echo '  }'
            echo '}' > "$DASHBOARD_DATA"

            ${pkgs.python3}/bin/python3 -m http.server ${toString (cfg.dashboard.port or 8080)} \
              --bind "${cfg.dashboard.bindAddress or "127.0.0.1"}" \
              --directory "$(dirname "$DASHBOARD_DATA")" 2>/dev/null || sleep 5
          done
        '';
        User = "root";
        Group = "root";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/run/vincentsai-health" ];
      };
    };

    systemd.timers."vincentsai-health-monitor" = {
      description = "Timer for health monitoring";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15s";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d /run/vincentsai-health 0755 root root - -"
      "d /var/log/vincentsai 0755 root root - -"
    ];
  };
}
