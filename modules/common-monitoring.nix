# nix-modules/modules/common-monitoring.nix
{ pkgs, lib, ... }:

let
  cfg = config.vincents-ai.common-monitoring or { };
in
{
  options.vincents-ai.common-monitoring = with lib; {
    enable = mkEnableOption "Common Monitoring Stack (Prometheus, Grafana, Alertmanager)";

    prometheusPort = mkOption {
      type = types.port;
      default = 9090;
      description = "Port for Prometheus server";
    };

    nodeExporterPort = mkOption {
      type = types.port;
      default = 9100;
      description = "Port for Node Exporter";
    };

    alertmanagerPort = mkOption {
      type = types.port;
      default = 9093;
      description = "Port for Alertmanager";
    };

    grafanaPort = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for Grafana dashboard";
    };

    grafanaEnable = mkEnableOption "Grafana dashboard" // { default = true; };
    grafanaAdminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = "Grafana admin password";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      exporters = {
        node = {
          enable = true;
          port = cfg.nodeExporterPort;
          enabledCollectors = [
            "systemd"
            "textfile"
            "processes"
            "interrupts"
            "tcpstat"
            "netstat"
            "conntrack"
          ];
          extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" ];
        };
        systemd = {
          enable = true;
        };
      };

      scrapeConfigs = [
        {
          job_name = "node_exporter_local";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.nodeExporterPort}" ];
            }
          ];
        }
      ];

      alertmanagers = [
        {
          scheme = "http";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.alertmanagerPort}" ];
            }
          ];
        }
      ];

      rules = [
        (pkgs.writeText "common-alerts.yml" (builtins.toJSON {
          groups = [
            {
              name = "common-system";
              rules = [
                {
                  alert = "InstanceDown";
                  expr = "up == 0";
                  for = "1m";
                  labels = { severity = "critical"; };
                  annotations = {
                    summary = "Instance {{ $labels.instance }} down";
                    description = "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute.";
                  };
                }
              ];
            }
          ];
        }))
      ];
    };

    services.prometheus.alertmanager = {
      enable = true;
      port = cfg.alertmanagerPort;
      configuration = {
        route = {
          group_by = [ "alertname" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "1h";
          receiver = "default-receiver";
        };
        receivers = [
          {
            name = "default-receiver";
          }
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter-text-files 0775 node_exporter node_exporter -"
    ];

    services.grafana = lib.mkIf cfg.grafanaEnable {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafanaPort;
          http_addr = "0.0.0.0";
        };
        security = {
          admin_user = "admin";
          admin_password = cfg.grafanaAdminPassword;
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            isDefault = true;
          }
        ];
      };
    };
  };
}
