# nix-modules/modules/common-dns.nix
{ pkgs, lib, ... }:

let
  cfg = config.vincents-ai.common-dns or { };
  domain = cfg.domain or "lan.local";
  gatewayIpv4 = cfg.gatewayIpv4 or "192.168.1.1";
  gatewayIpv6 = cfg.gatewayIpv6 or "::1";
  tsigKeyPath = "/var/lib/knot/keys/kea-ddns.key";

  dnscollectorConfig = pkgs.writeText "dnscollector.yml" ''
    global:
      trace:
        verbose: true

    pipelines:
      - name: tap
        dnstap:
          listen-ip: 127.0.0.1
          listen-port: 6001
        transforms:
          normalize:
            qname-lowercase: true
        routing-policy:
          forward: [ console, logfile, metrics ]

      - name: console
        stdout:
          mode: text

      - name: logfile
        logfile:
          file-path: /var/log/dnscollector/queries.log
          max-size: 100
          mode: json

      - name: metrics
        prometheus:
          listen-ip: 127.0.0.1
          listen-port: 9142
          prometheus-prefix: '';

  knotConfigTemplate = ''
    server:
      listen: 127.0.0.1@5353
      listen: ::1@5353

    log:
      - target: syslog
        any: info

    key:
      - id: kea-ddns
        algorithm: hmac-sha256
        secret: TSIG_SECRET_PLACEHOLDER

    acl:
      - id: kea_acl
        address: 127.0.0.1
        key: kea-ddns
        action: update

    zone:
      - domain: ${domain}
        storage: /var/lib/knot/zones
        file: ${domain}.zone
        acl: kea_acl

      - domain: ${reverseZone}
        storage: /var/lib/knot/zones
        file: ${reverseZone}.zone
        acl: kea_acl

      - domain: ${ipv6ReverseZoneName}
        storage: /var/lib/knot/zones
        file: ipv6-reverse.zone
        acl: kea_acl
  '';

  reverseZone = builtins.replaceStrings ["."] ["-"] domain + "-reverse";
  ipv6ReverseZoneName = "ip6.arpa";

  forwardZone = pkgs.writeText "${domain}.zone" (
    ''
      $ORIGIN ${domain}.
      $TTL 300

      @   IN  SOA  ns1.${domain}. admin.${domain}. (
                  2024101401  ; serial
                  3600        ; refresh
                  1800        ; retry
                  604800      ; expire
                  300 )       ; minimum

      @     IN  NS   ns1.${domain}.
      ns1   IN  A    ${gatewayIpv4}
      ns1   IN  AAAA ${gatewayIpv6}
      @     IN  A    ${gatewayIpv4}
      cache IN  A    ${gatewayIpv4}
      cache IN  AAAA ${gatewayIpv6}
    ''
  );

  ipv4ReverseZone = pkgs.writeText "${reverseZone}.zone" (
    ''
      $ORIGIN ${reverseZone}.
      $TTL 300

      @   IN  SOA  ns1.${domain}. admin.${domain}. (
                  2024101401  ; serial
                  3600        ; refresh
                  1800        ; retry
                  604800      ; expire
                  300 )       ; minimum

      @   IN  NS   ns1.${domain}.
    ''
  );

  ipv6ReverseZone = pkgs.writeText "ipv6-reverse.zone" ''
    $ORIGIN ${ipv6ReverseZoneName}.
    $TTL 300

    @   IN  SOA  ns1.${domain}. admin.${domain}. (
                2024101401  ; serial
                3600        ; refresh
                1800        ; retry
                604800      ; expire
                300 )       ; minimum

    @   IN  NS   ns1.${domain}.
  '';
in
{
  options.vincents-ai.common-dns = with lib; {
    enable = mkEnableOption "Common DNS Services (Knot DNS + Kresd)";

    domain = mkOption {
      type = types.str;
      default = "lan.local";
      description = "Primary domain name";
    };

    gatewayIpv4 = mkOption {
      type = types.str;
      default = "192.168.1.1";
      description = "Gateway IPv4 address";
    };

    gatewayIpv6 = mkOption {
      type = types.str;
      default = "::1";
      description = "Gateway IPv6 address";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.knot-setup = {
      description = "Setup Knot DNS TSIG key and zones";
      wantedBy = [ "multi-user.target" ];
      before = [ "knot.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /var/lib/knot/keys /var/lib/knot/zones

        if [ ! -f /var/lib/knot/keys/kea-ddns.secret ]; then
          ${pkgs.knot-dns}/bin/keymgr -t kea-ddns hmac-sha256 | ${pkgs.gnugrep}/bin/grep '^secret: ' | ${pkgs.gawk}/bin/awk '{print $2}' | head -n 1 > /var/lib/knot/keys/kea-ddns.secret
        fi

        TSIG_SECRET=$(head -n 1 /var/lib/knot/keys/kea-ddns.secret | tr -d '[:space:]')

        cat > /var/lib/knot/knotd.conf << 'EOF'
        ${knotConfigTemplate}
        EOF

        sed -i "s|TSIG_SECRET_PLACEHOLDER|$TSIG_SECRET|g" /var/lib/knot/knotd.conf

        cp ${forwardZone} /var/lib/knot/zones/${domain}.zone
        cp ${ipv4ReverseZone} /var/lib/knot/zones/${reverseZone}.zone
        cp ${ipv6ReverseZone} /var/lib/knot/zones/ipv6-reverse.zone

        chown -R knot:knot /var/lib/knot
        chmod 640 /var/lib/knot/keys/kea-ddns.secret
        chmod 644 /var/lib/knot/knotd.conf
      '';
    };

    services.knot = {
      enable = true;
      settingsFile = "/var/lib/knot/knotd.conf";
    };

    services.kresd = {
      enable = true;
      listenPlain = [
        "127.0.0.1:53"
        "${gatewayIpv4}:53"
        "[::1]:53"
        "[${gatewayIpv6}]:53"
      ];
      extraConfig = ''
        cache.size = 100 * MB

        policy.add(policy.suffix(policy.STUB({'127.0.0.1@5353'}), {
          todname('${domain}.'),
          todname('${reverseZone}.'),
          todname('${ipv6ReverseZoneName}.')
        }))

        modules.load('dnstap')
        dnstap.config({
          socket_path = 'tcp:127.0.0.1:6001',
          identity = 'kresd',
          version = 'kresd 5.x',
          client = { log_queries = true, log_responses = true }
        })
      '';
    };

    systemd.tmpfiles.rules = [
      "d /var/cache/knot-resolver 0700 knot-resolver knot-resolver - -"
    ];

    systemd.services."kresd@1".after = [ "dnscollector.service" ];
    systemd.services."kresd@1".wants = [ "dnscollector.service" ];

    services.prometheus.exporters.bind = {
      enable = false;
    };

    systemd.services."kresd@".serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    };

    systemd.services.dnscollector = {
      description = "DNS Collector for query logging and metrics";
      after = [
        "network.target"
        "kresd@1.service"
      ];
      wants = [ "kresd@1.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "dnscollector";
        Group = "dnscollector";
        ExecStart = "${pkgs.go-dnscollector}/bin/go-dnscollector -config ${dnscollectorConfig}";
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/log/dnscollector" ];

        LogsDirectory = "dnscollector";
        StateDirectory = "dnscollector";
      };
    };

    users.users.dnscollector = {
      isSystemUser = true;
      group = "dnscollector";
    };

    users.groups.dnscollector = { };
  };
}
