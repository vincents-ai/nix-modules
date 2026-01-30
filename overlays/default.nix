{ pkgs, lib, ... }:

{
  perSystem = { system, ... }:
    let
      pkgs = import <nixpkgs> { inherit system; };
    in
    {
      overlays = {
        default = final: prev: {
          vincents-ai = rec {
            enableUnfreePackages = true;
          };

          vincents-ai-vim = prev.vim.override {
            lua = prev.lua5_1;
          };
        };

        dev-overlay = final: prev: {
          devtools = {
            enable = true;
          };
        };

        hardware-overlay = final: prev: {
          hardware = {
            enableOpenGL = true;
            enableVulkan = true;
          };
        };
      };
    };
}
