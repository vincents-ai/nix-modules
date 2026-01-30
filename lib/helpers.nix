{ lib }:

with lib;

{
  # Validation functions for configuration values
  validators = {
    # Validate a URL is HTTPS
    isHttpsUrl = value:
      if builtins.isString value && lib.hasPrefix "https://" value
      then true
      else throw "Value must be an HTTPS URL, got: ${toString value}";

    # Validate a path is within home directory
    isSafePath = homeDir: value:
      let
        resolved = builtins.toString value;
        normalizedHome = builtins.toString homeDir;
        isSafe = lib.hasPrefix normalizedHome resolved;
        hasTraversal = lib.hasInfix ".." resolved;
      in
      if !isSafe || hasTraversal
      then throw "Path '${value}' is not safe or contains path traversal"
      else true;

    # Validate a port number
    isValidPort = value:
      if builtins.isInt value && value >= 1 && value <= 65535
      then true
      else throw "Invalid port number: ${toString value}";

    # Validate an IP address (IPv4)
    isValidIPv4 = value:
      if builtins.isString value &&
         builtins.match "^([0-9]{1,3}\\.){3}[0-9]{1,3}$" value != null
      then true
      else throw "Invalid IPv4 address: ${value}";
  };

  # Hardware detection helpers
  hardwareDetection = {
    # Check if system is a laptop
    isLaptop = detected:
      detected.system.isLaptop or false;

    # Check if system has NVIDIA GPU
    hasNvidiaGpu = detected:
      detected.gpu.nvidia or false;

    # Check if system has AMD GPU
    hasAmdGpu = detected:
      detected.gpu.amd or false;

    # Check if system has Intel GPU
    hasIntelGpu = detected:
      detected.gpu.intel or false;

    # Get total memory in GB
    getMemoryGB = detected:
      let
        memMB = detected.memory.totalMB or 0;
      in
      if memMB > 0 then "${toString (memMB / 1024)}GB" else "Unknown";

    # Check if on battery
    isOnBattery = detected:
      detected.powerState.onBattery or false;

    # Check if AC is available
    hasAcPower = detected:
      detected.powerState.hasAc or false;
  };

  # Security helpers
  security = {
    # Create hardened systemd service config
    hardenSystemdService = baseConfig:
      baseConfig // {
        Service = (baseConfig.Service or { }) // {
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
        };
      };

    # Create secure directory permissions
    secureDirConfig = path: mode:
      {
        "${path}" = {
          mode = mode;
          user = "root";
          group = "root";
        };
      };
  };

  # Shell integration helpers
  shellHelpers = {
    # Generate shell aliases from a list
    generateAliases = aliasMap:
      builtins.listToAttrs (
        map (entry: {
          name = builtins.elemAt entry 0;
          value = builtins.elemAt entry 1;
        }) aliasMap
      );

    # Common development aliases
    devAliases = {
      ll = "eza -la --header";
      la = "eza -la";
      lt = "eza --tree";
      cat = "bat";
      grep = "ripgrep";
      top = "btop";
      df = "duf";
      du = "dust";
    };
  };

  # Profile management helpers
  profileHelpers = {
    # List of available profiles
    availableProfiles = [
      "base"
      "development"
      "office"
      "multimedia"
      "gaming"
      "server"
      "minimal"
    ];

    # Create profile option
    mkProfileOption = name: {
      enable = mkEnableOption "${name} profile";
    };
  };
}
