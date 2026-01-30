{ lib, nix-modules, pkgs }:

lib.nixosTest {
  name = "basic-server-test";

  nodes.machine = { ... }: {
    imports = [
      ./configuration.nix
      nix-modules.nixosModules.common
    ];

    networking = {
      hostName = "test-server";
      firewall.allowedTCPPorts = [ 80 443 ];
    };

    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        root = pkgs.writeTextDir "index.html" "Welcome to Basic Server";
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-active prometheus.service")
    machine.succeed("systemctl is-active node-exporter.service")
    machine.succeed("systemctl is-active alertmanager.service")
    machine.succeed("systemctl is-active grafana.service")
    machine.succeed("systemctl is-active knot.service")
    machine.succeed("systemctl is-active kresd@1.service")
    machine.succeed("systemctl is-active fail2ban.service")
    machine.succeed("systemctl is-active nftables.service")
    machine.succeed("curl -s http://localhost | grep -q 'Welcome'")
    print("All services are running correctly!")
  '';
}
