import pytest
from pytest_bdd import scenario, given, when, then, parsers

from nixos_bridge import machine


@scenario('features/webserver.feature', 'Nginx is running and serving content')
def test_nginx_running():
    pass


@scenario('features/webserver.feature', 'Prometheus is available for metrics')
def test_prometheus_running():
    pass


@scenario('features/webserver.feature', 'Node exporter collects system metrics')
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
