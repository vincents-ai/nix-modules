{
  description = "BDD Test Setup Example - Behavior-driven development testing for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modules.url = "github:vincents-ai/vincents-ai/nix-modules";
  };

  outputs = { self, nixpkgs, nix-modules }: {
    checks.x86_64-linux.vm-test = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      featureFile = pkgs.writeText "webserver.feature" ''
        Feature: Webserver Availability
          As a system administrator
          I want the webserver to be reachable
          So that users can access the site

          Scenario: Nginx is running and serving content
            Given the machine is booted
            When I check the systemd unit "nginx.service"
            Then the service should be active
            And the webserver should return "Welcome to NixOS"

          Scenario: Prometheus is available for metrics
            Given the machine is booted
            When I check the systemd unit "prometheus.service"
            Then the service should be active
            And Prometheus should be listening on port 9090

          Scenario: Node exporter collects system metrics
            Given the machine is booted
            When I check the systemd unit "node-exporter.service"
            Then the service should be active
      '';

      testSteps = pkgs.writeText "test_steps.py" ''
        import pytest
        from pytest_bdd import scenario, given, when, then, parsers

        from nixos_bridge import machine

        @scenario('${featureFile}', 'Nginx is running and serving content')
        def test_nginx_running():
            pass

        @scenario('${featureFile}', 'Prometheus is available for metrics')
        def test_prometheus_running():
            pass

        @scenario('${featureFile}', 'Node exporter collects system metrics')
        def test_node_exporter_running():
            pass

        @given("the machine is booted")
        def machine_booted():
            machine.wait_for_unit("default.target")

        @when(parsers.parse('I check the systemd unit "{unit}"'))
        def check_unit(unit):
            result = machine.succeed(f"systemctl is-active {unit}")
            assert result.strip() == "active"

        @then("the service should be active")
        def service_active():
            pass

        @then(parsers.parse('the webserver should return "{content}"'))
        def check_content(content):
            output = machine.succeed("curl -sSf http://localhost")
            assert content in output

        @then(parsers.parse('Prometheus should be listening on port {port}'))
        def check_prometheus_port(port):
            machine.succeed(f"curl -sSf http://localhost:{port}/metrics")
      '';
    in
      pkgs.testers.nixosTest {
        name = "bdd-webserver-test";

        nodes.machine = { pkgs, ... }: {
          imports = [
            ./configuration.nix
            nix-modules.nixosModules.common
          ];

          services.nginx = {
            enable = true;
            virtualHosts.localhost.root = pkgs.writeTextDir "index.html" "Welcome to NixOS";
          };

          networking.firewall.allowedTCPPorts = [ 80 ];
        };

        extraPythonPackages = p: with p; [
          pytest
          pytest-bdd
        ];

        testScript = ''
          import sys
          import pytest
          import types

          bridge = types.ModuleType("nixos_bridge")
          bridge.machine = machine
          bridge.nodes = nodes
          sys.modules["nixos_bridge"] = bridge

          print(">>> Starting BDD Test Runner")
          exit_code = pytest.main(["-v", "-s", "${testSteps}"])

          if exit_code != 0:
              raise Exception("BDD Tests Failed")
          print(">>> BDD Tests Passed Successfully")
        '';
      };
  };
}
