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
