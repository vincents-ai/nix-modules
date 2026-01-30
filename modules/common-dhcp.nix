{
  config,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-dhcp or { };
  enabled = cfg.enable or false;

  domain = cfg.domain or "lan.local";
  gatewayIpv4 = cfg.gatewayIpv4 or "192.168.1.1";
  lanInterface = cfg.lanInterface or "eth0";
  dhcpRangeStart = cfg.dhcpRangeStart or "192.168.1.100";
  dhcpRangeEnd = cfg.dhcpRangeEnd or "192.168.1.200";
  ipv6Prefix = cfg.ipv6Prefix or "fd00:1::/64";

  reverseZone = builtins.replaceStrings ["."] ["-"] domain + "-reverse";
  ipv6ReverseZoneName = "ip6.arpa";
in
{
  options.vincents-ai.common-dhcp = with lib; {
    enable = mkEnableOption "Kea DHCP Server Configuration";

    domain = mkOption {
      type = types.str;
      default = "lan.local";
      description = "DNS domain suffix for DHCP clients";
    };

    gatewayIpv4 = mkOption {
      type = types.str;
      default = "192.168.1.1";
      description = "Default gateway IPv4 address";
    };

    lanInterface = mkOption {
      type = types.str;
      default = "eth0";
      description = "LAN interface for DHCP server";
    };

    dhcpRangeStart = mkOption {
      type = types.str;
      default = "192.168.1.100";
      description = "DHCP pool start address";
    };

    dhcpRangeEnd = mkOption {
      type = types.str;
      default = "192.168.1.200";
      description = "DHCP pool end address";
    };

    ipv6Prefix = mkOption {
      type = types.str;
      default = "fd00:1::/64";
      description = "IPv6 prefix for DHCPv6";
    };

    staticLeases = mkOption {
      type = types.listOf (types.submodule {
        options = {
          macAddress = mkOption {
            type = types.str;
            description = "Client MAC address";
          };
          ipAddress = mkOption {
            type = types.str;
            description = "Reserved IP address";
          };
          hostname = mkOption {
            type = types.str;
            description = "Client hostname";
          };
        };
      });
      default = [ ];
      description = "Static DHCP lease reservations";
    };
  };

  config = lib.mkIf enabled {
    systemd.services.kea-ddns-setup = {
      description = "Setup Kea DDNS TSIG key";
      after = [ "knot-setup.service" ];
      wants = [ "knot-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      before = [
        "kea-dhcp4-server.service"
        "kea-dhcp6-server.service"
        "kea-dhcp-ddns-server.service"
      ];
      unitConfig = {
        ConditionPathExists = "/var/lib/knot/keys/kea-ddns.secret";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /var/lib/kea
        cp /var/lib/knot/keys/kea-ddns.secret /var/lib/kea/ddns-key.secret
        chown kea:kea /var/lib/kea/ddns-key.secret
        chmod 640 /var/lib/kea/ddns-key.secret
      '';
    };

    systemd.paths.kea-ddns-setup = {
      description = "Watch for Knot TSIG key file";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathExists = "/var/lib/knot/keys/kea-ddns.secret";
        Unit = "kea-ddns-setup.service";
      };
    };

    services.kea = {
      dhcp4 = {
        enable = true;
        settings = {
          interfaces-config = {
            interfaces = [ lanInterface ];
            service-sockets-max-retries = -1;
            service-sockets-retry-wait-time = 5000;
          };

          lease-database = {
            type = "memfile";
            persist = true;
          };

          dhcp-ddns = {
            enable-updates = true;
            server-ip = "127.0.0.1";
            server-port = 53001;
            sender-ip = "0.0.0.0";
            sender-port = 0;
            max-queue-size = 1024;
            ncr-protocol = "UDP";
            ncr-format = "JSON";
          };

          ddns-send-updates = true;
          ddns-override-no-update = true;
          ddns-override-client-update = true;
          ddns-replace-client-name = "when-present";
          ddns-generated-prefix = "dhcp";
          ddns-qualifying-suffix = domain;

          valid-lifetime = 86400;
          renew-timer = 43200;
          rebind-timer = 64800;

          client-classes = [
            {
              name = "legacy_bios";
              test = "option[93].hex == 0x0000";
              boot-file-name = "netboot.xyz.kpxe";
            }
            {
              name = "uefi_64";
              test = "option[93].hex == 0x0007 or option[93].hex == 0x0009";
              boot-file-name = "netboot.xyz.efi";
            }
          ];

          subnet4 = [
            {
              id = 1;
              subnet = "${gatewayIpv4}/24";
              pools = [
                { pool = "${dhcpRangeStart} - ${dhcpRangeEnd}"; }
              ];
              next-server = gatewayIpv4;

              option-data = [
                {
                  name = "routers";
                  data = gatewayIpv4;
                }
                {
                  name = "domain-name-servers";
                  data = gatewayIpv4;
                }
                {
                  name = "domain-search";
                  data = domain;
                }
              ];
              reservations = map (lease: {
                hw-address = lease.macAddress;
                ip-address = lease.ipAddress;
                hostname = lease.hostname;
              }) cfg.staticLeases;
            }
          ];
        };
      };

      dhcp6 = {
        enable = true;
        settings = {
          interfaces-config = {
            interfaces = [ lanInterface ];
            service-sockets-max-retries = -1;
            service-sockets-retry-wait-time = 5000;
          };

          lease-database = {
            type = "memfile";
            persist = true;
          };

          dhcp-ddns = {
            enable-updates = true;
            server-ip = "127.0.0.1";
            server-port = 53001;
            sender-ip = "0.0.0.0";
            sender-port = 0;
            max-queue-size = 1024;
            ncr-protocol = "UDP";
            ncr-format = "JSON";
          };

          ddns-send-updates = true;
          ddns-override-no-update = true;
          ddns-override-client-update = true;
          ddns-replace-client-name = "when-present";
          ddns-generated-prefix = "dhcp6";
          ddns-qualifying-suffix = domain;

          preferred-lifetime = 43200;
          valid-lifetime = 86400;
          renew-timer = 21600;
          rebind-timer = 32400;

          subnet6 = [
            {
              id = 1;
              subnet = ipv6Prefix;
              pools = [
                { pool = "${lib.removeSuffix "::/64" ipv6Prefix}::1000 - ${lib.removeSuffix "::/64" ipv6Prefix}::2000"; }
              ];
            }
          ];
        };
      };

      dhcp-ddns = {
        enable = true;
        settings = {
          ip-address = "127.0.0.1";
          port = 53001;
          dns-server-timeout = 500;
          ncr-protocol = "UDP";
          ncr-format = "JSON";

          tsig-keys = [
            {
              name = "kea-ddns";
              algorithm = "hmac-sha256";
              secret-file = "/var/lib/kea/ddns-key.secret";
            }
          ];

          forward-ddns = {
            ddns-domains = [
              {
                name = "${domain}.";
                key-name = "kea-ddns";
                dns-servers = [
                  { ip-address = "127.0.0.1"; port = 5353; }
                ];
              }
            ];
          };

          reverse-ddns = {
            ddns-domains = [
              {
                name = "${reverseZone}.";
                key-name = "kea-ddns";
                dns-servers = [
                  { ip-address = "127.0.0.1"; port = 5353; }
                ];
              }
              {
                name = "${ipv6ReverseZoneName}.";
                key-name = "kea-ddns";
                dns-servers = [
                  { ip-address = "127.0.0.1"; port = 5353; }
                ];
              }
            ];
          };
        };
      };
    };

    services.avahi = {
      enable = true;
      reflector = true;
      allowInterfaces = [ lanInterface ];
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
  };
}
