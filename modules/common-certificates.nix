{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-certificates or { };
in
{
  options.vincents-ai.common-certificates = with lib; {
    enable = mkEnableOption "Certificate Management";

    certificates = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.enum [ "acme" "selfSigned" ];
              default = "acme";
              description = "Certificate type";
            };

            domain = mkOption {
              type = types.str;
              description = "Certificate domain name";
            };

            email = mkOption {
              type = types.str;
              default = "admin@example.com";
              description = "Email for certificate registration";
            };

            renewBefore = mkOption {
              type = types.str;
              default = "30d";
              description = "Renew certificate before this period";
            };

            staging = mkOption {
              type = types.bool;
              default = false;
              description = "Use staging environment for testing";
            };

            dnsProvider = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "DNS provider for ACME DNS-01 challenge";
            };

            reloadServices = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Services to reload after renewal";
            };
          };
        }
      );
      default = { };
      description = "Certificate configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openssl
      certbot
    ];

    systemd.services = {
      "vincentsai-certificate-monitor" = {
        description = "Certificate expiry monitoring";
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "certificate-monitor" ''
            STATE_DIR="/run/vincentsai-secrets"
            LOG_FILE="/var/log/vincentsai/certificate-monitor.log"
            WARNING_THRESHOLDS="30 14 7 1"

            mkdir -p "$(dirname "$LOG_FILE")"

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: cert: ''
                cert_file="/run/vincentsai-secrets/${name}.crt"
                if [ -f "$cert_file" ] && command -v openssl >/dev/null 2>&1; then
                  expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
                  if [ -n "$expiry_date" ]; then
                    expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                    current_timestamp=$(date +%s)
                    days_until=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${name} expires in $days_until days" | tee -a "$LOG_FILE"
                  fi
                fi
              '') cfg.certificates
            )}
          '';
          User = "root";
          Group = "root";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ "/run/vincentsai-secrets" "/var/log/vincentsai" ];
        };
      };

      "vincentsai-certificate-renewal" = {
        description = "Certificate renewal service";
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "certificate-renewal" ''
            LOG_FILE="/var/log/vincentsai/certificate-renewal.log"
            STATE_DIR="/run/vincentsai-secrets"

            mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking certificate renewal" | tee -a "$LOG_FILE"

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: cert: ''
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Renewal check for ${name}" | tee -a "$LOG_FILE"
              '') cfg.certificates
            )}
          '';
          User = "root";
          Group = "root";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            "/run/vincentsai-secrets"
            "/var/backups/vincentsai-secrets"
            "/var/log/vincentsai"
            "/etc/letsencrypt"
            "/var/lib/letsencrypt"
          ];
        };
      };
    };

    systemd.timers = {
      "vincentsai-certificate-monitor" = {
        description = "Timer for certificate monitoring";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      "vincentsai-certificate-renewal" = {
        description = "Timer for certificate renewal";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "2h";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/acme-challenges 0755 root root - -"
    ];

    services.logrotate.settings."vincentsai-certificates" = {
      files = [
        "/var/log/vincentsai/certificate-monitor.log"
        "/var/log/vincentsai/certificate-renewal.log"
      ];
      frequency = "weekly";
      rotate = 4;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 root root";
    };
  };
}
