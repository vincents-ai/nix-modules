{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-policy-routing or { };
in
{
  options.vincents-ai.common-policy-routing = with lib; {
    enable = mkEnableOption "Policy-Based Routing";

    routingTables = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Human-readable table name";
            };

            priority = mkOption {
              type = types.int;
              default = 100;
              description = "Table priority for ordering";
            };

            defaultRoute = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Default route gateway for this table";
            };
          };
        }
      );
      default = { };
      description = "Routing tables configuration";
    };

    policies = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            rules = mkOption {
              type = types.listOf (
                types.submodule {
                  options = {
                    name = mkOption {
                      type = types.str;
                      description = "Policy rule name";
                    };

                    enabled = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Whether this policy rule is enabled";
                    };

                    priority = mkOption {
                      type = types.int;
                      default = 1000;
                      description = "Rule priority (lower = higher priority)";
                    };

                    match = mkOption {
                      type = types.submodule {
                        options = {
                          sourceAddress = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Source address or network (CIDR)";
                          };

                          destinationAddress = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Destination address or network (CIDR)";
                          };

                          protocol = mkOption {
                            type = types.nullOr (types.enum [ "tcp" "udp" "icmp" "all" ]);
                            default = null;
                            description = "IP protocol";
                          };

                          sourcePort = mkOption {
                            type = types.nullOr types.int;
                            default = null;
                            description = "Source port";
                          };

                          destinationPort = mkOption {
                            type = types.nullOr types.int;
                            default = null;
                            description = "Destination port";
                          };

                          inputInterface = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Input interface name";
                          };

                          outputInterface = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Output interface name";
                          };
                        };
                      };
                      description = "Match criteria for this policy";
                    };

                    action = mkOption {
                      type = types.submodule {
                        options = {
                          action = mkOption {
                            type = types.enum [ "route" "multipath" "blackhole" "prohibit" "unreachable" ];
                            description = "Action to take when rule matches";
                          };

                          table = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Routing table name";
                          };

                          tables = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "Routing tables for multipath";
                          };

                          weights = mkOption {
                            type = types.attrsOf types.int;
                            default = { };
                            description = "Weight for each table in multipath";
                          };
                        };
                      };
                      description = "Action to take when rule matches";
                    };
                  };
                }
              );
              default = [ ];
              description = "Policy rules";
            };
          };
        }
      );
      default = { };
      description = "Policy rules configuration";
    };

    enableProxyArp = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Proxy ARP on internal interfaces";
    };

    internalInterfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Internal interfaces for Proxy ARP";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      iproute2
      iptables
    ];

    networking.nftables.enable = true;

    systemd.services = {
      "vincentsai-policy-routing" = {
        description = "Policy-Based Routing Setup";
        wantedBy = [ "network.target" ];
        after = [ "network.target" ];
        before = [ "network-online.target" ];

        path = with pkgs; [
          iproute2
          iptables
          procps
          coreutils
          gnugrep
          gawk
          gnused
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "policy-routing-setup" ''
            set -euo pipefail

            mkdir -p /etc/iproute2
            touch /etc/iproute2/rt_tables || true

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: table: ''
                if ! grep -q "^${toString table.priority} ${name}$" /etc/iproute2/rt_tables 2>/dev/null; then
                  echo "${toString table.priority} ${name}" >> /etc/iproute2/rt_tables
                fi
              '') cfg.routingTables
            )}

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: table: ''
                ip route flush table ${name} || true
                ${lib.optionalString (table.defaultRoute != null) ''
                  ip route replace default via ${table.defaultRoute} table ${name}
                ''}
              '') cfg.routingTables
            )}

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (policyName: policy:
                lib.concatStringsSep "\n" (
                  lib.map (rule:
                    let
                      fromSrc = lib.optionalString (rule.match.sourceAddress != null) "from ${rule.match.sourceAddress}";
                      toDst = lib.optionalString (rule.match.destinationAddress != null) "to ${rule.match.destinationAddress}";
                      iif = lib.optionalString (rule.match.inputInterface != null) "iif ${rule.match.inputInterface}";
                      oif = lib.optionalString (rule.match.outputInterface != null) "oif ${rule.match.outputInterface}";
                      actionTable = lib.optionalString (rule.action.table != null) "table ${rule.action.table}";
                    in
                    lib.optionalString rule.enabled ''
                      ip rule add ${fromSrc} ${toDst} ${iif} ${oif} priority ${toString rule.priority} ${actionTable}
                    ''
                  ) policy.rules
                )
              ) cfg.policies
            )}

            sysctl -w net.ipv4.ip_forward=1 || true
            sysctl -w net.ipv6.conf.all.forwarding=1 || true

            ${lib.optionalString cfg.enableProxyArp ''
              for iface in ${lib.concatStringsSep " " cfg.internalInterfaces}; do
                if [ -d "/proc/sys/net/ipv4/conf/$iface" ]; then
                  sysctl -w net.ipv4.conf.$iface.proxy_arp=1 || true
                fi
              done
            ''}
          '';
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
}
