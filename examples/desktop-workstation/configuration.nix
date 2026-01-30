{ config, pkgs, ... }:

{
  imports = [
    nix-modules.nixosModules.common
  ];

  networking.hostName = "desktop-workstation";

  # Desktop environment configuration
  vincents-ai.common-desktop = {
    enable = true;
    desktopEnvironment = "gnome";
    enableDisplayManager = true;
    displayManager = "gdm";
    enableWayland = true;
    enableX11 = false;
    enableGraphicsDrivers = true;
    enableTouchpad = true;
    enableTouchscreen = true;
    enableFonts = true;
    enableIconThemes = true;
    enableCursorThemes = true;
  };

  # Audio configuration
  vincents-ai.common-audio = {
    enable = true;
    backend = "pipewire";
    enableBluetoothAudio = true;
    enableJack = true;
    enableAlsa = true;
    enableVolumeManagement = true;
    enableSoundEffects = true;
    enableSpatialAudio = false;
    realtimePriority = true;
    sampleRate = 48000;
    bufferSize = 1024;
  };

  # Basic system services
  services = {
    logind = {
      enable = true;
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
    };
    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 5;
    };
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
  };

  # User configuration
  users.users.shift = {
    isNormalUser = true;
    description = "Shift User";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "bluetooth"
    ];
  };

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [
      "quiet"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
    ];
  };

  # System state version
  system.stateVersion = "24.11";
}
