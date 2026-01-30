{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-secrets or { };

  secretTypes = {
    apiKey = "API Key";
    password = "Password";
    tlsCertificate = "TLS Certificate";
    wireguardKey = "WireGuard Key";
    tsigKey = "TSIG Key";
    oauthToken = "OAuth Token";
  };
in
{
  options.vincents-ai.common-secrets = with lib; {
    enable = mkEnableOption "Secrets Management";

    secrets = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.enum (builtins.attrNames secretTypes);
              description = "Type of secret";
              default = "apiKey";
            };

            key = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Secret key value";
            };

            password = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Secret password value";
            };

            certificate = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to TLS certificate file";
            };

            private_key = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to private key file";
            };

            rotation = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    enabled = mkOption {
                      type = types.bool;
                      default = false;
                      description = "Enable automatic rotation";
                    };

                    interval = mkOption {
                      type = types.str;
                      default = "90d";
                      description = "Rotation interval";
                    };

                    backup = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Create backup before rotation";
                    };
                  };
                }
              );
              default = null;
            };
          };
        }
      );
      default = { };
      description = "Secrets configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      "vincentsai-secrets-setup" = {
        description = "Setup vincents-ai secrets";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /run/vincentsai-secrets
          mkdir -p /var/backups/vincentsai-secrets
          mkdir -p /var/log/vincentsai
        '';
      };

      "vincentsai-secrets-health" = {
        description = "Secrets health monitoring";
        after = [ "network-online.target" ];
        path = with pkgs; [ coreutils openssl ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "secrets-health-check" ''
            HEALTH_DIR="/run/vincentsai-secrets"
            LOG_FILE="/var/log/vincentsai/secrets-health.log"
            mkdir -p "$HEALTH_DIR" "$(dirname "$LOG_FILE")"

            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: secret: ''
              if [ -n "${secret.certificate or ""}" ] && [ -f "${secret.certificate}" ]; then
                if command -v openssl >/dev/null 2>&1; then
                  expiry_date=$(openssl x509 -in "${secret.certificate}" -noout -enddate 2>/dev/null | cut -d= -f2)
                  if [ -n "$expiry_date" ]; then
                    expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                    current_timestamp=$(date +%s)
                    days_until=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                    if [ "$days_until" -lt 7 ]; then
                      echo "CRITICAL: ${name} expires in $days_until days" | tee -a "$LOG_FILE"
                    fi
                  fi
                fi
              fi
            '') cfg.secrets)}
          '';
          User = "root";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ "/run/vincentsai-secrets" "/var/log/vincentsai" ];
        };
      };
    };

    systemd.timers."vincentsai-secrets-health" = {
      description = "Timer for secrets health monitoring";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    systemd.tmpfiles.rules = [
      "d /run/vincentsai-secrets 0755 root root - -"
      "d /var/backups/vincentsai-secrets 0700 root root - -"
      "d /var/log/vincentsai 0755 root root - -"
    ];
  };
}
