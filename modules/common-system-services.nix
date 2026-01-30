{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vincents-ai.common-system-services;
in
{
  options.vincents-ai.common-system-services = {
    enable = mkEnableOption "common system services configuration";

    enableAvahi = mkEnableOption "Avahi zeroconf service discovery";
    enableCUPS = mkEnableOption "CUPS printing service";
    enableSANE = mkEnableOption "SANE scanner support";
    enableNetworkManager = mkEnableOption "NetworkManager";
    enableResolved = mkEnableOption "systemd-resolved DNS resolution";
    enableTimesync = mkEnableOption "systemd-timesyncd time synchronization";
    enableLogind = mkEnableOption "systemd-logind session management";
    enableUdev = mkEnableOption "udev device management";

    enableCron = mkEnableOption "cron job scheduling";
    enableTmpfiles = mkEnableOption "tmpfiles.d configuration";

    enablePolkit = mkEnableOption "PolicyKit authentication";
    enableDBus = mkEnableOption "D-Bus message bus";

    printing = {
      enable = mkEnableOption "printing subsystem";
      defaultPrinter = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Set as default printer";
      };
    };

    scanner = {
      enable = mkEnableOption "scanner support";
      networkScanning = mkEnableOption "network scanner discovery";
    };

    zeroconf = {
      enable = mkEnableOption "zeroconf service discovery";
      hostName = mkOption {
        type = types.str;
        default = "nixos";
        description = "Zeroconf hostname";
      };
      domain = mkOption {
        type = types.str;
        default = "local";
        description = "Zeroconf domain";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.enableAvahi {
      services.avahi = {
        enable = true;
        nssmdns = true;
        openFirewall = false;
        publish = {
          enable = true;
          addresses = true;
          hostnames = true;
          domain = true;
        };
      };

      networking.firewall.allowedUDPPorts = [ 5353 ];
    })

    (mkIf cfg.enableCUPS {
      services.printing = {
        enable = true;
        allowFrom = [ "all" ];
        browsing = true;
        defaultPrinter = cfg.printing.defaultPrinter;
      };

      networking.firewall.allowedTCPPorts = [ 631 ];

      environment.systemPackages = with pkgs; [
        cups-filters
        gutenprint
        hplip
      ];
    })

    (mkIf cfg.enableSANE {
      services.saned = {
        enable = true;
        networks = [ "192.168.0.0/16" "172.16.0.0/12" "10.0.0.0/8" ];
      };

      hardware.sane = {
        enable = true;
        backends = [ "plustek" "epson2" "brother" "hpaio" ];
      };
    })

    (mkIf cfg.printing.enable {
      environment.systemPackages = with pkgs; [
        simple-scan
        system-config-printer
      ];
    })

    (mkIf cfg.scanner.enable {
      hardware.sane = {
        enable = true;
        networkScanning = mkIf cfg.scanner.networkScanning true;
      };
    })

    (mkIf cfg.enableNetworkManager {
      networking.networkmanager = {
        enable = true;
        dns = "systemd";
        wifi = {
          backend = "iwd";
          powersave = true;
        };
      };
    })

    (mkIf cfg.enableResolved {
      systemd.resolved = {
        enable = true;
        dnssec = true;
        fallbackDNS = [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" ];
        logLevel = "info";
      };
    })

    (mkIf cfg.enableTimesync {
      systemd.timesyncd = {
        enable = true;
        ntpServers = [
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
          "3.nixos.pool.ntp.org"
        ];
        rootDistanceMaxSec = 5;
        pollIntervalMinSec = 32;
        pollIntervalMaxSec = 2048;
      };
    })

    (mkIf cfg.enableLogind {
      systemd.logind = {
        enable = true;
        handlePowerKey = "suspend";
        handleLidSwitch = "suspend";
        handleLidSwitchDocked = "ignore";
        ignoreLid = true;
        IdleAction = "suspend";
        IdleActionSec = "30min";
      };
    })

    (mkIf cfg.enableUdev {
      systemd.udev = {
        enable = true;
        rules = [
          ''
            # GPU device nodes
            KERNEL=="card*", SUBSYSTEM=="drm", GROUP="video", MODE="0666"
          ''
        ];
      };
    })

    (mkIf cfg.enableCron {
      services.cron = {
        enable = true;
        systemCronJobs = [
          {
            user = "root";
            clock = "*";
            command = "nix-collect-garbage -d 2>/dev/null || true";
            environment = {
              PATH = "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin";
            };
          }
        ];
      };
    })

    (mkIf cfg.enableTmpfiles {
      systemd.tmpfiles.rules = [
        "d /tmp 1777 root root - -"
        "d /var/tmp 1777 root root - -"
        "d /var/cache 755 root root - -"
        "d /var/log 755 root root - -"
        "d /run/user 755 root root - -"
      ];
    })

    (mkIf cfg.enablePolkit {
      security.polkit = {
        enable = true;
      };
    })

    (mkIf cfg.enableDBus {
      services.dbus.enable = true;
    })

    (mkIf cfg.zeroconf.enable {
      services.avahi = {
        nssmdns4 = true;
        nssmdns6 = true;
        publish = {
          userName = cfg.zeroconf.hostName;
          domain = cfg.zeroconf.domain;
        };
      };
    })
  ]);
}
