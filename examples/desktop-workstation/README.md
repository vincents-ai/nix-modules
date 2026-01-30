# Desktop Workstation Example

This example demonstrates how to configure a desktop NixOS system with common
productivity tools using the `nix-modules` repository.

Key modules used:
- `common-desktop.nix` - Desktop environment configuration (GNOME/Hyprland)
- `common-audio.nix` - Audio subsystem (PipeWire/PulseAudio)
- `common-home.nix` - Home Manager integration and user configuration

## Usage

1. Enter the development shell:
   ```bash
   cd examples/desktop-workstation
   nix develop
   ```

2. Build the system configuration:
   ```bash
   nix build .#nixosConfigurations.desktop.config.system.build
   ```

3. Deploy to hardware:
   ```bash
   sudo nixos-rebuild switch --flake .#desktop-workstation
   ```

## Desktop Environments

The example supports multiple desktop environments:

### GNOME (Default)
- GDM display manager
- GNOME Shell with extensions
- Adwaita theme

### Hyprland
- SDDM display manager
- Wayland compositor
- Custom keybindings

To switch environments, update `configuration.nix`:
```nix
vincents-ai.common-desktop.desktopEnvironment = "hyprland";
```

## Audio Configuration

The audio module supports:
- PipeWire (default, recommended)
- PulseAudio (legacy)

Features:
- Bluetooth audio support
- JACK support for pro audio
- ALSA configuration
- Real-time scheduling (RTKit)

## Home Manager Integration

The home module configures:
- Shell (Zsh with Oh My Zsh)
- Editor (Neovim with plugins)
- Terminal (Alacritty)
- Browser (Firefox)
- Productivity tools (Bitwarden, Joplin)
- XDG directories
- SSH and GPG configuration

## Hardware Support

- Graphics drivers (OpenGL, Vulkan)
- Touchpad configuration
- Touchscreen support
- Tablet/stylus support (Wacom)
