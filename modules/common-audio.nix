{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vincents-ai.common-audio;
in
{
  options.vincents-ai.common-audio = {
    enable = mkEnableOption "common audio configuration";

    backend = mkOption {
      type = types.enum [ "pipewire" "pulseaudio" "none" ];
      default = "pipewire";
      description = "Audio backend to use";
    };

    enableBluetoothAudio = mkEnableOption "Bluetooth audio support";
    enableJack = mkEnableOption "JACK audio support";
    enableAlsa = mkEnableOption "ALSA configuration";

    enableSpatialAudio = mkEnableOption "spatial audio (pipewire plugin)";
    enableAudioPlugins = mkEnableOption "audio plugin support (LADSPA, LV2, VST)";

    enableVolumeManagement = mkEnableOption "system volume management";
    enableSoundEffects = mkEnableOption "system sound effects";

    sampleRate = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Default sample rate (e.g., 44100, 48000, 96000)";
    };

    bufferSize = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Audio buffer size in frames";
    };

    realtimePriority = mkEnableOption "real-time audio scheduling";
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.backend == "pipewire") {
      services.pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse = {
          enable = true;
          support32Bit = true;
        };
        jack = {
          enable = mkIf cfg.enableJack true;
          support32Bit = true;
        };
        wireplumber = {
          enable = true;
        };
      };

      environment.etc = {
        "pipewire/pipewire.conf.d/00-vincents-ai".text = ''
          context.properties = {
             default.clock.rate = ${toString (cfg.sampleRate or 48000)}
             default.clock.quantum = ${toString (cfg.bufferSize or 1024)}
             default.clock.min-quantum = 64
             default.clock.max-quantum = 8192
          }
        '';
      };
    })

    (mkIf (cfg.backend == "pulseaudio") {
      services.pulseaudio = {
        enable = true;
        support32Bit = mkIf cfg.enableAudioPlugins true;
        config = [
          ''
            load-module module-switch-on-port-available
            load-module module-always-sink
          ''
        ];
      };
    })

    (mkIf cfg.enableBluetoothAudio {
      services.bluetooth = {
        enable = true;
        enableMediaSink = true;
        enableMediaSource = true;
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      environment.systemPackages = with pkgs; [
        bluez-tools
        pulsemixer
      ];
    })

    (mkIf cfg.enableAlsa {
      environment.etc = {
        "asound.conf".text = ''
          pcm.!default {
              type plug
              slave.pcm "null"
          }

          ctl.!default {
              type null
          }
        '';
      };
    })

    (mkIf cfg.enableSpatialAudio {
      services.pipewire.extraConfig = {
        "99-vincents-ai-spatial" = ''
          context.modules = [
            { name = libfilter-pw }
          ]
        '';
      };
    })

    (mkIf cfg.enableAudioPlugins {
      environment.systemPackages = with pkgs; [
        ladspaPlugins
        lv2Plugins
        lsp-plugins
        synthv1
      ];
    })

    (mkIf cfg.enableVolumeManagement {
      programs.pamixer = {
        enable = true;
      };

      environment.systemPackages = with pkgs; [
        pulsemixer
        pamixer
      ];
    })

    (mkIf cfg.enableSoundEffects {
      environment.systemPackages = with pkgs; [
        sound-theme-freedesktop
      ];
    })

    (mkIf cfg.realtimePriority {
      security.rtkit = {
        enable = true;
      };

      users.groups.audio.members = [ "root" ];
    })
  ]);
}
