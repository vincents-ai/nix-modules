{ lib }:

let
  inherit (lib) mkOption types optionalAttrs mapAttrsToList concatStringsSep filter mapAttrs mapAttrs';

  healthCheckTypes = {
    interface = {
      description = "Network interface health check";
      requiredFields = [ "interface" ];
      optionalFields = [
        "checkType"
        "expectedState"
        "linkQuality"
        "congestion"
        "timeout"
      ];
    };

    routing = {
      description = "Routing table health check";
      requiredFields = [ "route" ];
      optionalFields = [
        "checkType"
        "gateway"
        "metric"
        "table"
        "timeout"
      ];
    };

    connectivity = {
      description = "Network connectivity health check";
      requiredFields = [ "target" ];
      optionalFields = [
        "protocol"
        "port"
        "timeout"
        "retries"
        "expectedLatency"
      ];
    };

    query = {
      description = "DNS query health check";
      requiredFields = [ "target" "query" ];
      optionalFields = [
        "expectedResult"
        "recordType"
        "timeout"
        "retries"
        "cacheCheck"
      ];
    };

    zone = {
      description = "DNS zone integrity health check";
      requiredFields = [ "zone" ];
      optionalFields = [
        "serialCheck"
        "soaCheck"
        "transferCheck"
        "timeout"
      ];
    };

    resolver = {
      description = "DNS resolver performance check";
      requiredFields = [ "queries" ];
      optionalFields = [
        "latencyThreshold"
        "successRateThreshold"
        "cacheHitRateThreshold"
        "timeout"
      ];
    };

    dhcp-server = {
      description = "DHCP server health check";
      requiredFields = [ "interface" ];
      optionalFields = [
        "leaseCheck"
        "poolUtilization"
        "responseTime"
        "timeout"
      ];
    };

    dhcp-database = {
      description = "DHCP database integrity check";
      requiredFields = [ "path" ];
      optionalFields = [
        "checkType"
        "leaseCount"
        "conflictCheck"
        "timeout"
      ];
    };

    ids = {
      description = "Intrusion Detection System health check";
      requiredFields = [ "process" ];
      optionalFields = [
        "rulesLoaded"
        "packetRate"
        "dropRate"
        "alertRate"
        "timeout"
      ];
    };

    firewall = {
      description = "Firewall rules health check";
      requiredFields = [ "table" ];
      optionalFields = [
        "chain"
        "ruleCount"
        "policyCheck"
        "timeout"
      ];
    };

    process = {
      description = "Process health check";
      requiredFields = [ "name" ];
      optionalFields = [
        "user"
        "memoryLimit"
        "cpuLimit"
        "restartCount"
        "timeout"
      ];
    };

    filesystem = {
      description = "Filesystem health check";
      requiredFields = [ "path" ];
      optionalFields = [
        "checkType"
        "minFreeSpace"
        "permissions"
        "inodeCheck"
        "timeout"
      ];
    };

    system = {
      description = "System resource health check";
      requiredFields = [ "resource" ];
      optionalFields = [
        "threshold"
        "warning"
        "critical"
        "timeout"
      ];
    };

    database = {
      description = "Database integrity health check";
      requiredFields = [ "path" ];
      optionalFields = [
        "checkType"
        "tableCheck"
        "connectionCheck"
        "timeout"
      ];
    };

    port = {
      description = "Port connectivity health check";
      requiredFields = [ "port" ];
      optionalFields = [
        "protocol"
        "host"
        "timeout"
        "retries"
      ];
    };

    script = {
      description = "Custom script health check";
      requiredFields = [ "path" ];
      optionalFields = [
        "timeout"
        "args"
        "expectedExitCode"
      ];
    };

    http = {
      description = "HTTP endpoint health check";
      requiredFields = [ "url" ];
      optionalFields = [
        "method"
        "expectedStatus"
        "expectedContent"
        "timeout"
        "headers"
      ];
    };

    metric = {
      description = "Metric-based health check";
      requiredFields = [ "metric" ];
      optionalFields = [
        "threshold"
        "operator"
        "window"
        "source"
      ];
    };
  };

  validateHealthCheck = check:
    let
      checkType = check.type or (throw "Health check missing 'type' field");
      typeDef = healthCheckTypes.${checkType} or (throw "Unknown health check type: ${checkType}");
      missingRequired = filter (field: !(check ? ${field}) || check.${field} == null) typeDef.requiredFields;
      hasAllRequired = missingRequired == [ ];
    in
    assert lib.assertMsg hasAllRequired
      "Health check type '${checkType}' missing required fields: ${concatStringsSep ", " missingRequired}";
    check;

  validateServiceHealthChecks = serviceName: checks:
    let
      validatedChecks = map validateHealthCheck checks;
      hasValidInterval = if checks ? interval && checks.interval != null then
        (builtins.isString checks.interval && builtins.match "^[0-9]+[smh]$" checks.interval != null)
      else
        true;
      hasValidTimeout = if checks ? timeout && checks.timeout != null then
        (builtins.isString checks.timeout && builtins.match "^[0-9]+[smh]$" checks.timeout != null)
      else
        true;
    in
    assert lib.assertMsg hasValidInterval
      "Service '${serviceName}' has invalid interval format: ${toString (checks.interval or "null")}";
    assert lib.assertMsg hasValidTimeout
      "Service '${serviceName}' has invalid timeout format: ${toString (checks.timeout or "null")}";
    checks // { checks = validatedChecks; };

  generateHealthCheckScript = check:
    let
      timeout = if (check.timeout or null) != null then check.timeout else "5s";
    in
    if check.type == "interface" then
      ''
        expected_state=${check.expectedState or "UP"}
        check_type=${check.checkType or "basic"}
        if ! ip link show ${check.interface} >/dev/null 2>&1; then
          echo "Interface ${check.interface} does not exist"
          exit 1
        fi
        if ! ip link show ${check.interface} | grep -q "state $expected_state"; then
          echo "Interface ${check.interface} not in expected state $expected_state"
          exit 1
        fi
        echo "Interface ${check.interface} check passed"
      ''
    else if check.type == "routing" then
      ''
        check_type=${check.checkType or "basic"}
        table=${check.table or "main"}
        if ! ip route show table $table ${check.route} >/dev/null 2>&1; then
          echo "Route ${check.route} not found in table $table"
          exit 1
        fi
        echo "Routing check for ${check.route} passed"
      ''
    else if check.type == "connectivity" then
      ''
        protocol=${check.protocol or "tcp"}
        port=${toString (check.port or 80)}
        target=${check.target}
        if [ "$protocol" = "tcp" ]; then
          timeout ${timeout} nc -zv "$target" "$port" >/dev/null 2>&1
        elif [ "$protocol" = "udp" ]; then
          timeout ${timeout} nc -zuv "$target" "$port" >/dev/null 2>&1
        elif [ "$protocol" = "icmp" ]; then
          timeout ${timeout} ping -c 1 -W 1 "$target" >/dev/null 2>&1
        else
          echo "Unsupported protocol: $protocol"
          exit 1
        fi
      ''
    else if check.type == "query" then
      ''
        record_type=${check.recordType or "A"}
        result=$(timeout ${timeout} dig @${check.target} ${check.query} $record_type +short 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$result" ]; then
          echo "DNS query failed for ${check.query}"
          exit 1
        fi
        echo "DNS query check passed"
      ''
    else if check.type == "zone" then
      ''
        if ! timeout ${timeout} dig @localhost ${check.zone} SOA +short >/dev/null 2>&1; then
          echo "SOA check failed for zone ${check.zone}"
          exit 1
        fi
        echo "Zone integrity check passed for ${check.zone}"
      ''
    else if check.type == "dhcp-server" then
      ''
        if ! pgrep -f "dhcp" >/dev/null 2>&1; then
          echo "DHCP server process not found"
          exit 1
        fi
        echo "DHCP server check passed"
      ''
    else if check.type == "dhcp-database" then
      ''
        db_path=${check.path}
        if [ ! -f "$db_path" ]; then
          echo "DHCP database file not found: $db_path"
          exit 1
        fi
        if ! timeout ${timeout} sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
          echo "DHCP database integrity check failed"
          exit 1
        fi
        echo "DHCP database check passed"
      ''
    else if check.type == "firewall" then
      ''
        table=${check.table or "filter"}
        if ! iptables -t $table -L >/dev/null 2>&1; then
          echo "Cannot access iptables table $table"
          exit 1
        fi
        echo "Firewall check passed"
      ''
    else if check.type == "system" then
      ''
        resource=${check.resource}
        threshold=${toString (check.threshold or 80)}
        case "$resource" in
          "cpu")
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
            echo "CPU usage: $cpu_usage%"
            ;;
          "memory")
            memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
            echo "Memory usage: $memory_usage%"
            ;;
          "disk")
            disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            echo "Disk usage: $disk_usage%"
            ;;
        esac
        echo "System resource check passed"
      ''
    else if check.type == "port" then
      ''
        protocol=${check.protocol or "tcp"}
        host=${check.host or "localhost"}
        if [ "$protocol" = "tcp" ]; then
          timeout ${timeout} nc -zv "$host" ${toString check.port} >/dev/null 2>&1
        elif [ "$protocol" = "udp" ]; then
          timeout ${timeout} nc -zuv "$host" ${toString check.port} >/dev/null 2>&1
        fi
      ''
    else if check.type == "http" then
      ''
        expected_status=${toString (check.expectedStatus or 200)}
        response=$(timeout ${timeout} curl -s -o /dev/null -w "%{http_code}" "${check.url}")
        if [ "$response" != "$expected_status" ]; then
          echo "HTTP status $response, expected $expected_status"
          exit 1
        fi
        echo "HTTP check passed"
      ''
    else
      throw "Unsupported health check type: ${check.type}";

  generateHealthCheckMetrics = healthChecks:
    let
      serviceMetrics = mapAttrsToList (serviceName: serviceConfig: ''
        # HELP vincentsai_health_check_status Health check status (1 = healthy, 0 = unhealthy)
        # TYPE vincentsai_health_check_status gauge
        vincentsai_health_check_status{service="${serviceName}"} 1
        vincentsai_health_check_check_count{service="${serviceName}"} ${toString (builtins.length (serviceConfig.checks or []))}
      '') healthChecks;
    in
    concatStringsSep "\n" serviceMetrics;

  defaultHealthChecks = {
    "network-interfaces" = {
      checks = [
        { type = "interface"; interface = "eth0"; expectedState = "UP"; }
      ];
      interval = "30s";
      timeout = "5s";
    };

    "routing" = {
      checks = [
        { type = "routing"; route = "default"; }
        { type = "connectivity"; target = "8.8.8.8"; protocol = "icmp"; }
      ];
      interval = "60s";
      timeout = "10s";
    };

    "dns-resolution" = {
      checks = [
        { type = "query"; target = "localhost"; query = "example.com"; }
      ];
      interval = "30s";
      timeout = "5s";
    };

    "dhcp-server" = {
      checks = [
        { type = "dhcp-server"; interface = "eth0"; }
        { type = "port"; port = 67; protocol = "udp"; }
      ];
      interval = "60s";
      timeout = "10s";
    };

    "monitoring" = {
      checks = [
        { type = "port"; port = 9100; protocol = "tcp"; host = "localhost"; }
        { type = "port"; port = 9090; protocol = "tcp"; host = "localhost"; }
      ];
      interval = "30s";
      timeout = "10s";
    };
  };

in
{
  inherit
    healthCheckTypes
    validateHealthCheck
    validateServiceHealthChecks
    generateHealthCheckScript
    generateHealthCheckMetrics
    defaultHealthChecks
    ;

  processHealthChecks = healthChecks:
    let
      validatedChecks = mapAttrs validateServiceHealthChecks healthChecks;
      metrics = generateHealthCheckMetrics validatedChecks;
    in
    {
      inherit validatedChecks metrics;
    };

  mergeHealthChecks = userChecks:
    let
      merged = defaultHealthChecks // userChecks;
    in
    mapAttrs (serviceName: userConfig:
      let
        defaultConfig = defaultHealthChecks.${serviceName} or { };
      in
      defaultConfig // userConfig
    ) merged;
}
