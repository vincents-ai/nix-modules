{ config, ... }:

{
  # Home Manager configuration
  home = {
    username = "shift";
    homeDirectory = "/home/shift";
    stateVersion = "24.11";
  };

  # Shell configuration
  vincents-ai.common-home.shell = {
    enable = true;
    defaultShell = "zsh";
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # Editor configuration
  vincents-ai.common-home.editor = {
    enable = true;
    type = "nvim";
    enableVimMode = true;
  };

  # Terminal configuration
  vincents-ai.common-home.terminal = {
    enable = true;
    type = "alacritty";
    enableShellIntegration = true;
  };

  # Browser configuration
  vincents-ai.common-home.browser = {
    enable = true;
    type = "firefox";
  };

  # Productivity tools
  vincents-ai.common-home.productivity = {
    enable = true;
    enablePasswordManager = true;
    enableFileManager = true;
    enableNotes = true;
  };

  # XDG directories
  vincents-ai.common-home.enableXdgDirs = true;

  # SSH configuration
  vincents-ai.common-home.enableSsh = true;

  # GPG configuration
  vincents-ai.common-home.enableGpg = true;

  # Dotfiles management (disabled by default)
  vincents-ai.common-home.enableDotfiles = false;

  # Programs
  programs = {
    git = {
      enable = true;
      userName = "Shift";
      userEmail = "shift@example.com";
    };
  };
}
