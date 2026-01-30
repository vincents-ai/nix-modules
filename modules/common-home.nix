{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vincents-ai.common-home;
in
{
  options.vincents-ai.common-home = {
    enable = mkEnableOption "home manager integration and common home configuration";

    shell = {
      enable = mkEnableOption "shell configuration";
      defaultShell = mkOption {
        type = types.enum [ "zsh" "bash" "fish" ];
        default = "zsh";
        description = "Default shell";
      };
      enableZshIntegration = mkEnableOption "Zsh integration";
      enableBashIntegration = mkEnableOption "Bash integration";
      enableFishIntegration = mkEnableOption "Fish integration";
    };

    editor = {
      enable = mkEnableOption "editor configuration";
      type = mkOption {
        type = types.enum [ "nvim" "vscode" "helix" "none" ];
        default = "nvim";
        description = "Editor to configure";
      };
      enableVimMode = mkEnableOption "vi mode in shell";
    };

    terminal = {
      enable = mkEnableOption "terminal configuration";
      type = mkOption {
        type = types.enum [ "alacritty" "wezterm" "kitty" "foot" "none" ];
        default = "alacritty";
        description = "Terminal emulator to configure";
      };
      enableShellIntegration = mkEnableOption "shell integration in terminal";
    };

    browser = {
      enable = mkEnableOption "browser configuration";
      type = mkOption {
        type = types.enum [ "firefox" "chrome" "chromium" "none" ];
        default = "none";
        description = "Browser to configure";
      };
    };

    productivity = {
      enable = mkEnableOption "productivity tools";
      enablePasswordManager = mkEnableOption "password manager integration";
      enableFileManager = mkEnableOption "file manager integration";
      enableNotes = mkEnableOption "notes application";
    };

    enableXdgDirs = mkEnableOption "XDG directory configuration";
    enableGpg = mkEnableOption "GPG configuration";
    enableSsh = mkEnableOption "SSH configuration";

    enableDotfiles = mkEnableOption "dotfiles management";
    dotfilesRepo = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "URL of dotfiles repository";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.shell.enable {
      programs = {
        zsh = mkIf cfg.enableZshIntegration {
          enable = true;
          oh-my-zsh = {
            enable = true;
            theme = "robbyrussell";
            plugins = [ "git" "docker" "nix-shell" ];
          };
          syntaxHighlighting.enable = true;
          autosuggestions.enable = true;
        };

        bash = mkIf cfg.enableBashIntegration {
          enable = true;
          bashrc = ''
            export PATH="$HOME/.local/bin:$PATH"
            export EDITOR="${toString cfg.editor.type}"
          '';
        };

        fish = mkIf cfg.enableFishIntegration {
          enable = true;
          useConfigFile = true;
          promptInit = ''
            fish_add_path -g ~/.local/bin
          '';
        };
      };

      home.shellAliases = {
        ll = "eza -la --header";
        la = "eza -la";
        lt = "eza --tree";
        cat = "bat";
        grep = "rg";
        top = "btop";
      };
    })

    (mkIf (cfg.editor.type == "nvim") {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        withPython = true;
        withRuby = true;
        withNodeJs = true;
        plugins = with pkgs.vimPlugins; [
          nvim-treesitter
          nvim-treesitter-textobjects
         vim-startify
          telescope-nvim
          nvim-cmp
          LSP-zero-nvim
        ];
        extraConfig = ''
          set number
          set relativenumber
          set tabstop=4
          set shiftwidth=4
          set expandtab
          set smartindent
          set wrap
          set linebreak
          set clipboard=unnamed
          set mouse=a
          set termguicolors
          set showcmd
          set laststatus=2
          set hidden
          set ignorecase
          set smartcase
          set incsearch
          set hlsearch
        '';
      };
    })

    (mkIf (cfg.editor.type == "helix") {
      programs.helix = {
        enable = true;
      };
    })

    (mkIf (cfg.terminal.type == "alacritty") {
      programs.alacritty = {
        enable = true;
        settings = {
          font.size = 12;
          font.offset.x = 0;
          font.offset.y = 0;
          window.dimensions.columns = 80;
          window.dimensions.lines = 24;
          colors.primary.background = "#1a1b26";
          colors.primary.foreground = "#a9b1d6";
          drawing.concurrency = 8;
          live_config_reload = true;
        };
      };
    })

    (mkIf (cfg.terminal.type == "wezterm") {
      programs.wezterm = {
        enable = true;
        extraConfig = ''
          local wezterm = require 'wezterm'
          local config = {}

          config.font = wezterm.font 'FiraCode Nerd Font'
          config.font_size = 12
          config.colors = {
            background = '#1a1b26',
            foreground = '#a9b1d6',
          }

          return config
        '';
      };
    })

    (mkIf (cfg.terminal.type == "kitty") {
      programs.kitty = {
        enable = true;
        settings = {
          font_family = "FiraCode Nerd Font";
          font_size = 12;
          background_opacity = "0.95";
          dynamic_background_opacity = true;
          shell_integration = mkIf cfg.terminal.enableShellIntegration "enabled";
        };
      };
    })

    (mkIf (cfg.browser.type == "firefox") {
      programs.firefox = {
        enable = true;
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
          };
        };
      };
    })

    (mkIf (cfg.browser.type == "chrome" || cfg.browser.type == "chromium") {
      programs = let
        browserPkg = if cfg.browser.type == "chrome" then pkgs.google-chrome else pkgs.chromium;
      in {
        ${cfg.browser.type} = {
          enable = true;
          package = browserPkg;
          enablePdfJs = true;
        };
      };
    })

    (mkIf cfg.productivity.enablePasswordManager {
      programs = {
        bitwarden = {
          enable = true;
        };
        gnome-keyring = {
          enable = true;
        };
      };

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
      };
    })

    (mkIf cfg.productivity.enableFileManager {
      programs = {
        nnn = {
          enable = true;
          enableMouse = true;
          useNerdIcons = true;
        };
      };

      home.shellAliases.n = "nnn";
    })

    (mkIf cfg.productivity.enableNotes {
      programs.joplin = {
        enable = true;
      };
    })

    (mkIf cfg.enableXdgDirs {
      xdg = {
        enable = true;
        userDirs = {
          createDirectories = true;
          desktop = "$HOME/Desktop";
          documents = "$HOME/Documents";
          download = "$HOME/Downloads";
          music = "$HOME/Music";
          pictures = "$HOME/Pictures";
          videos = "$HOME/Videos";
          templates = "$HOME/Templates";
          publicshare = "$HOME/Public";
        };

        mimeApps = {
          enable = true;
          defaultApplications = {
            "text/plain" = "nvim.desktop";
            "text/x-python" = "nvim.desktop";
            "text/html" = "firefox.desktop";
          };
        };
      };
    })

    (mkIf cfg.enableGpg {
      programs.gpg = {
        enable = true;
        homedir = "$HOME/.gnupg";
      };

      home.file.".gnupg/gpg-agent.conf".text = ''
        allow-loopback-pinentry
        pinentry-program ${pkgs.pinentry-gtk}/bin/pinentry-gtk-2
      '';
    })

    (mkIf cfg.enableSsh {
      programs.ssh = {
        enable = true;
        includeUsersKnownHosts = false;
        knownHosts = [
          "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5qyAwIDu4nr/L3pYhPM8e7Q9iY3N/v/l/vWqBUq9s4xq3a4hK1a0b"
          "gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5GGlyZWFsIGN1cnZlcnRpdml0eSBzaWduaW5nIHByb2Nlc3Mgb3B0aW9ucw=="
        ];
        extraConfig = ''
          Host *
            AddKeysToAgent yes
            IdentitiesOnly yes
            HashKnownHosts yes
        '';
      };

      home.shellAliases.ssh-add-key = "ssh-add ~/.ssh/id_ed25519";
    })

    (mkIf cfg.enableDotfiles {
      programs.git = {
        enable = true;
        userName = "User";
        userEmail = "user@example.com";
        extraConfig = {
          init = {
            defaultBranch = "main";
          };
          pull = {
            rebase = true;
          };
        };
      };

      home.file = {
        ".config/git/ignore".source = "${pkgs.git}/etc/gitignore";
      };
    })
  ]);
}
