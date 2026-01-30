{ config, lib, ... }:

let
  cfg = config.vincents-ai.common-log-aggregation or { };
in
{
  options.vincents-ai.common-log-aggregation = with lib; {
    enable = mkEnableOption "Log Aggregation Framework";

    collector = mkOption {
      type = types.enum [ "fluent-bit" "fluentd" "filebeat" ];
      default = "fluent-bit";
      description = "Log collector type";
    };

    inputs = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Log input configurations";
    };

    outputs = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Log output configurations";
    };

    filters = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Log filter configurations";
    };

    retention = mkOption {
      type = types.submodule {
        options = {
          policies = mkOption {
            type = types.attrsOf types.attrs;
            default = {};
            description = "Log retention policies";
          };
        };
      };
      default = { };
      description = "Log retention configuration";
    };

    monitoring = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable log aggregation monitoring";
          };
        };
      };
      default = { };
      description = "Monitoring configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fluent-bit = lib.mkIf (cfg.collector == "fluent-bit") {
      enable = true;

      settings = {
        service = {
          log_level = "info";
          parsers_file = "/etc/fluent-bit/parsers.conf";
        };

        inputs = cfg.inputs;

        filters = cfg.filters;

        outputs = cfg.outputs;
      };
    };

    users.users.log-aggregation = {
      isSystemUser = true;
      group = "log-aggregation";
      home = "/var/lib/log-aggregation";
      createHome = true;
    };

    users.groups.log-aggregation = {};

    systemd.tmpfiles.rules = [
      "d /var/lib/log-aggregation 0750 log-aggregation log-aggregation -"
      "d /var/lib/log-aggregation/buffers 0750 log-aggregation log-aggregation -"
      "d /var/lib/log-aggregation/logs 0750 log-aggregation log-aggregation -"
    ];

    environment.systemPackages = with config.systemPackages; [
      fluent-bit
      jq
      curl
    ];
  };
}
