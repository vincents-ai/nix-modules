{ system
, nixpkgs ? null
}:

assert nixpkgs != null;

let
  pkgs = import nixpkgs { inherit system; };

  featureFileContent = ''
    Feature: Webserver Availability
      As a system administrator
      I want the webserver to be reachable
      So that users can access the site

      Scenario: Nginx is running and serving content
        Given the machine is booted
        When I check the systemd unit "nginx.service"
        Then the service should be active
        And the webserver should return "Welcome to NixOS"
  '';

  testStepsContent = ''
    import pytest
    from pytest_bdd import scenario, given, when, then, parsers

    from nixos_test import machine

    @scenario("FEATURE_FILE_PATH", "Nginx is running and serving content")
    def test_nginx_running():
        pass

    @given("the machine is booted")
    def machine_booted():
        machine.wait_for_unit("default.target")

    @when(parsers.parse('I check the systemd unit "{unit}"'))
    def check_unit(unit):
        assert machine.succeed(f"systemctl is-active {unit}").strip() == "active"

    @then("the service should be active")
    def service_active():
        pass

    @then(parsers.parse('the webserver should return "{content}"'))
    def check_content(content):
        output = machine.succeed("curl -sSf http://localhost")
        assert content in output
  '';

  featureFile = pkgs.writeText "webserver.feature" featureFileContent;
  testSteps = pkgs.writeText "test_steps.py" testStepsContent;
  testStepsContentRaw = builtins.readFile testSteps;
  featureFilePath = featureFile;
in
  pkgs.testers.nixosTest {
    name = "bdd-vm-test";
    skipTypeCheck = true;

    nodes.machine = { pkgs, ... }: {
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

      test_machine = types.ModuleType("nixos_test")
      test_machine.machine = machine
      sys.modules["nixos_test"] = test_machine

      print(">>> Starting BDD Test Runner")
      test_script = """${testStepsContentRaw}""".replace("FEATURE_FILE_PATH", "${featureFilePath}")
      import tempfile
      import os
      with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(test_script)
        temp_path = f.name
      try:
        exit_code = pytest.main(["-v", "-s", temp_path])
      finally:
        os.unlink(temp_path)

      if exit_code != 0:
          raise Exception("BDD Tests Failed")
    '';
  }
