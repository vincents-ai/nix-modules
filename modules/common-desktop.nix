{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vincents-ai.common-desktop;
in
{
  options.vincents-ai.common-desktop = {
    enable = mkEnableOption "common desktop environment configuration";

    desktopEnvironment = mkOption {
      type = types.enum [ "gnome" "kde" "hyprland" "sway" "none" ];
      default = "none";
      description = "Desktop environment to configure";
    };

    enableGraphicsDrivers = mkEnableOption "OpenGL and Vulkan hardware acceleration";
    enableTouchpad = mkEnableOption "touchpad configuration";
    enableTouchscreen = mkEnableOption "touchscreen configuration";
    enableTabletSupport = mkEnableOption "tablet and stylus support";
    enableDisplayManager = mkEnableOption "display manager (SDDM, GDM, LightDM)";

    displayManager = mkOption {
      type = types.enum [ "sddm" "gdm" "lightdm" "lxdm" ];
      default = "sddm";
      description = "Display manager to use";
    };

    enableWayland = mkEnableOption "Wayland support";
    enableX11 = mkEnableOption "X11 support";

    enableFonts = mkEnableOption "common fonts configuration";
    enableIconThemes = mkEnableOption "icon themes";
    enableCursorThemes = mkEnableOption "cursor themes";

    enablePlymouth = mkEnableOption " Plymouth boot splash";
    plymouthTheme = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Plymouth theme to use";
    };

    enableThemingIntegration = mkEnableOption "stylix theming integration";
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.desktopEnvironment != "none") {
      environment.sessionVariables = {
        XDG_CURRENT_DESKTOP = cfg.desktopEnvironment;
        XDG_SESSION_TYPE = if cfg.enableWayland then "wayland" else "x11";
      };
    })

    (mkIf cfg.enableGraphicsDrivers {
      hardware.opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (mkIf cfg.enableTouchpad {
      services.xserver.libinput = {
        enable = true;
        touchpad.clickMap = "two-finger-scrolling";
        touchpad.naturalScrolling = false;
        touchpad.tapping = true;
        touchpad.dwt = true;
      };
    })

    (mkIf cfg.enableTouchscreen {
      services.xserver.libinput = {
        enable = true;
        enableTablet = true;
      };
    })

    (mkIf cfg.enableTabletSupport {
      hardware.wacom = {
        enable = true;
        enableTabletPC = true;
      };
    })

    (mkIf cfg.enableDisplayManager {
      services.xserver.displayManager = {
        enable = true;
        defaultSession = "${cfg.desktopEnvironment}-etc";
      };

      services.displayManager = {
        inherit (cfg) displayManager;
        enable = true;
      };
    })

    (mkIf cfg.enableWayland {
      programs.wl-clipboard = {
        enable = true;
      };

      xdg.portal = {
        enable = true;
        wlr = true;
        configPackages = [ ];
      };
    })

    (mkIf cfg.enableX11 {
      services.xserver = {
        enable = true;
        layout = "us";
        xkbOptions = [ "grp:alt_shift_toggle" ];
      };
    })

    (mkIf cfg.enableFonts {
      fonts = {
        fonts = with pkgs; [
          noto-fonts
          noto-fonts-emoji
          liberation_ttf
          fira-code
          fira-code-symbols
        ];

        fontconfig = {
          enable = true;
          antialias = true;
          hinting = true;
          subpixel = {
            lcdfilter = "light";
            rgba = "rgb";
          };
        };
      };
    })

    (mkIf cfg.enableIconThemes {
      programs.icons = {
        enable = true;
        theme = "Adwaita";
      };
    })

    (mkIf cfg.enableCursorThemes {
      programs.cursor = {
        enable = true;
        theme = "Adwaita";
        size = 24;
      };
    })

    (mkIf cfg.enablePlymouth {
      boot.plymouth = {
        enable = true;
        theme = cfg.plymouthTheme or "bgrt";
      };
    })

    (mkIf cfg.enableThemingIntegration {
      imports = [
        (import (builtins.fetchTarball {
          url = "https://github.com/danth/stylix/tarball/master";
          sha256 = "sha256-0000000000000000000000000000000000000000";
        }) { })
      ];

      stylix = {
        enable = true;
        base16Scheme = {
          base00 = "181a1b";
          base01 = "282c34";
          base02 = "353b45";
          base03 = "4f5266";
          base04 = "7e8187";
          base05 = "abb2bf";
          base06 = "c0cc44";
          base07 = "c0cc44";
          base08 = "f22c40";
          base09 = "df5320";
          base0A = "d5911a";
          base0B = "5e8fce";
          base0C = "11a8cd";
          base0D = "794b91";
          base0E = "c43e18";
          base0F = "df5320";
        };
      };
    })
  ]);
}
