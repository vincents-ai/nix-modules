{ config, pkgs, ... }:

{
  imports = [
    nix-modules.nixosModules.common
  ];

  networking.hostName = "bdd-test-server";

  # Enable monitoring for testing
  vincents-ai.common-monitoring = {
    enable = true;
    prometheusPort = 9090;
    nodeExporterPort = 9100;
    alertmanagerPort = 9093;
    grafanaEnable = false;
  };

  # Basic security
  vincents-ai.common-security = {
    enable = true;
    enableFirewall = true;
    enableSysctlHardening = true;
    securityProfile = "standard";
  };

  # Nginx for testing
  services.nginx = {
    enable = true;
    virtualHosts.localhost = {
      root = pkgs.writeTextDir "index.html" "Welcome to NixOS";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  users.users.test = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "24.11";
}
