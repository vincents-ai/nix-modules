# BDD Test Setup Example

This example demonstrates how to use the BDD (Behavior-Driven Development) testing
framework with Nix and pytest-bdd for testing NixOS configurations.

## Overview

The BDD testing approach allows you to write tests in natural language (Gherkin)
that describe system behavior. These tests are then automatically converted to
Python test code using pytest-bdd.

## Usage

1. Enter the development shell:
   ```bash
   cd examples/bdd-test-setup
   nix develop
   ```

2. Run the BDD tests:
   ```bash
   nix build .#checks.x86_64-linux.vm-test
   ./result/bin/nixos-test-driver
   ```

3. Run tests directly:
   ```bash
   cd tests
   pytest -v
   ```

## Project Structure

```
bdd-test-setup/
├── flake.nix              # Flake configuration
├── configuration.nix      # NixOS system under test
├── tests/
│   ├── features/
│   │   └── webserver.feature    # Gherkin feature file
│   ├── steps/
│   │   └── test_steps.py        # Python step definitions
│   └── conftest.py              # Pytest configuration
└── README.md              # This file
```

## Writing Features

Features are written in Gherkin syntax:

```gherkin
Feature: Webserver Availability
  As a system administrator
  I want the webserver to be reachable
  So that users can access the site

  Scenario: Nginx is running and serving content
    Given the machine is booted
    When I check the systemd unit "nginx.service"
    Then the service should be active
    And the webserver should return "Welcome to NixOS"
```

## Step Definitions

Step definitions connect Gherkin steps to Python code:

```python
from pytest_bdd import given, when, then, parsers

@given("the machine is booted")
def machine_booted():
    machine.wait_for_unit("default.target")

@when(parsers.parse('I check the systemd unit "{unit}"'))
def check_unit(unit):
    assert machine.succeed(f"systemctl is-active {unit}").strip() == "active"

@then("the service should be active")
def service_active():
    pass
```

## Best Practices

1. **Independent Scenarios**: Each scenario should be able to run independently
2. **Business Language**: Avoid technical details like HTTP methods or status codes
3. **Reusable Steps**: Create steps that can be reused across multiple scenarios
4. **Clear Assertions**: Each then step should have a clear assertion

## Running in CI/CD

The test framework integrates with standard Nix CI:

```bash
# Run all checks including BDD tests
nix flake check

# Run specific test
nix build .#checks.x86_64-linux.vm-test
```

## Machine Bridging

The test framework provides a `machine` object that represents the NixOS VM
under test. This object has methods like:
- `machine.wait_for_unit(unit)` - Wait for a systemd unit
- `machine.succeed(command)` - Run a command and assert success
- `machine.fail(command)` - Run a command and expect failure
- `machine.copy_from_host(source, dest)` - Copy files from host to VM
