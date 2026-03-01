{config}: let
  sources = import ../npins;
  pkgs = sources.nixpkgs;
  nixos-raspberrypi = builtins.getFlake "github:nvmd/nixos-raspberrypi/refs/tags/v1.20260125.0";
  ssid = config.installer.ssid;
  pwd = config.installer.pwd;
in
  import (pkgs + "/nixos/lib/eval-config.nix") {
    specialArgs = {inherit nixos-raspberrypi ssid pwd;};
    system = "aarch64-linux";
    modules = [./sd-image.nix];
  }
