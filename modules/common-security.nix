{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vincents-ai.common-security;
in
{
  options.vincents-ai.common-security = {
    enable = mkEnableOption "system security hardening";

    enableHardenedKernel = mkEnableOption "hardened kernel parameters";
    enableSysctlHardening = mkEnableOption "sysctl kernel parameter hardening";

    enableFirewall = mkEnableOption "nftables firewall";
    enableFail2Ban = mkEnableOption "fail2ban intrusion prevention";

    enableAppArmor = mkEnableOption "AppArmor LSM";
    enableSELinux = mkEnableOption "SELinux (if supported)";

    enableCoreDumps = mkOption {
      type = types.bool;
      default = false;
      description = "Enable core dumps (not recommended for production)";
    };

    enableKptrRestrict = mkEnableOption "kernel pointer hiding (kptr_restrict)";
    enableDmesgRestrict = mkEnableOption "dmesg access restriction";

    networkHardening = {
      enable = mkEnableOption "network security hardening";
      ipv4Forwarding = mkOption {
        type = types.bool;
        default = false;
        description = "Enable IPv4 forwarding";
      };
      ipv6Forwarding = mkOption {
        type = types.bool;
        default = false;
        description = "Enable IPv6 forwarding";
      };
      disableICMPRedirects = mkOption {
        type = types.bool;
        default = true;
        description = "Disable ICMP redirects";
      };
    };

    sysctlSettings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional sysctl settings";
    };

    securityProfile = mkOption {
      type = types.enum [ "standard" "hardened" "paranoid" ];
      default = "standard";
      description = "Security profile level";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.enableHardenedKernel {
      boot.kernelParams = [
        "quiet"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "systemd.show_status=false"
        "systemd.log_level=3"
      ];

      boot.kernel.sysctl = {
        "kernel.randomize_va_space" = "2";
        "kernel.exec-shield" = "1";
        "kernel.core_uses_pid" = "1";
      };
    })

    (mkIf cfg.enableSysctlHardening {
      boot.kernel.sysctl = mkMerge [
        (mkIf cfg.enableKptrRestrict {
          "kernel.kptr_restrict" = "2";
        })

        (mkIf cfg.enableDmesgRestrict {
          "kernel.dmesg_restrict" = "1";
        })

        (mkIf (!cfg.enableCoreDumps) {
          "kernel.core_pattern" = "|/bin/false";
          "kernel.suid_dumpable" = "0";
        })

        (mkIf cfg.networkHardening.enable (mkMerge [
          {
            "net.ipv4.ip_forward" = if cfg.networkHardening.ipvForwarding then "1" else "0";
            "net.ipv6.conf.all.forwarding" = if cfg.networkHardening.ipv6Forwarding then "1" else "0";
            "net.ipv4.conf.all.accept_redirects" = "0";
            "net.ipv4.conf.all.send_redirects" = "0";
            "net.ipv4.conf.all.accept_source_route" = "0";
            "net.ipv4.conf.all.rp_filter" = "1";
            "net.ipv4.icmp_echo_ignore_broadcasts" = "1";
            "net.ipv4.icmp_ignore_bogus_error_responses" = "1";
          }
          (mkIf cfg.networkHardening.disableICMPRedirects {
            "net.ipv4.conf.default.accept_redirects" = "0";
            "net.ipv4.conf.default.send_redirects" = "0";
          })
        ]))

        cfg.sysctlSettings
      ];
    })

    (mkIf cfg.enableFirewall {
      networking.nftables = {
        enable = true;
        tables = {
          filter = {
            input = {
              type = "filter";
              hook = "input";
              priority = 0;
              rules = [
                "iif lo accept"
                "ip protocol icmp accept"
                "ip6 nexthdr icmpv6 accept"
                "ct state established,related accept"
              ];
            };
            forward = {
              type = "filter";
              hook = "forward";
              priority = 0;
              rules = [ "ct state established,related accept" ];
            };
            output = {
              type = "filter";
              hook = "output";
              priority = 0;
              rules = [ "oif lo accept" ];
            };
          };
        };
      };
    })

    (mkIf cfg.enableFail2Ban {
      services.fail2ban = {
        enable = true;
        maxretry = 5;
        bantime = 600;
        ignoreIP = [ "127.0.0.1" "::1" ];
        fail2banConfig = ''
          [DEFAULT]
          bantime = 600
          maxretry = 5
          findtime = 600
          ignoreip = 127.0.0.1/8 ::1
        '';
      };
    })

    (mkIf cfg.enableAppArmor {
      security.apparmor = {
        enable = true;
        policies = {
          enabled = [ ];
          disabled = [ ];
        };
      };
    })

    (mkIf (cfg.securityProfile == "hardened" || cfg.securityProfile == "paranoid") {
      security.tmp = {
        enable = true;
        sessions = {
          enable = true;
          initOnLogin = true;
        };
      };

      environment.variables = {
        MOZ_DISABLE_CONTENT_SANDBOX = "1";
        NIX_SKIP_SHELL_CHECK = "1";
      };
    })

    (mkIf (cfg.securityProfile == "paranoid") {
      boot.kernel.sysctl = {
        "net.ipv4.tcp_syncookies" = "1";
        "net.ipv4.conf.all.rp_filter" = "1";
        "net.ipv4.conf.default.rp_filter" = "1";
      };

      security.wrappers = {
        ping = {
          source = "${pkgs.iputils}/bin/ping";
          owner = "root";
          group = "root";
          setuid = true;
          permissions = "u-s,g-xs,o=";
        };
      };
    })
  ]);
}
