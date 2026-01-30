{ config, pkgs, ... }:

{
  imports = [
    # nix-modules are already imported via the flake
    # They provide options under vincents-ai.*
  ];

  networking = {
    hostName = "basic-server";
    firewall = {
      allowedTCPPorts = [ 80 443 ];
    };
  };

  # Enable the monitoring stack
  vincents-ai.common-monitoring = {
    enable = true;
    prometheusPort = 9090;
    nodeExporterPort = 9100;
    alertmanagerPort = 9093;
    grafanaEnable = true;
    grafanaAdminPassword = "admin";
  };

  # Enable DNS services
  vincents-ai.common-dns = {
    enable = true;
    domain = "lan.local";
    gatewayIpv4 = "192.168.1.1";
    gatewayIpv6 = "::1";
  };

  # Enable security hardening
  vincents-ai.common-security = {
    enable = true;
    enableFirewall = true;
    enableFail2Ban = true;
    enableSysctlHardening = true;
    enableKptrRestrict = true;
    enableDmesgRestrict = true;
    securityProfile = "standard";
  };

  # Basic system configuration
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "24.11";
}
