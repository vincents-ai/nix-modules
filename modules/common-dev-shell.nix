# nix-modules/modules/common-dev-shell.nix
{ pkgs, ... }:

{
  options.vincents-ai.common-dev-shell.enable = pkgs.lib.mkEnableOption "common development shell";

  config = pkgs.lib.mkIf config.vincents-ai.common-dev-shell.enable {
    devShells.default = pkgs.mkShell {
      name = "vincents-platform-dev";

      packages = with pkgs; [
        # Core tools
        git
        curl
        wget
        tmux

        # Kubernetes tools
        kubectl
        kind
        k9s
        helm

        # Container tools
        docker
        buildah
        podman

        # Database
        postgresql_16
        redis

        # Messaging
        nats-server

        # Rust toolchain
        rustc
        cargo
        rust-analyzer

        # Nix
        nix
        nil

        # Node.js and TypeScript toolchain
        nodejs_22
        bun
        nodePackages.typescript
        nodePackages.typescript-language-server
        nodePackages.npm
        nodePackages.pnpm

        # Development tools
        just
        jq
        yq
        bat
        ripgrep
        fd
        fzf
        eza
        tokei

        # System dependencies
        pkg-config
        openssl
        openssl.dev
        libudev-zero
        systemd
      ];

      # Environment variables
      RUST_BACKTRACE = "1";
      RUST_LOG = "info";
    };
  };
}
