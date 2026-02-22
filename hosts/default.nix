let
  sources = import ../npins;
  pkgs = sources.nixpkgs;
in
  import (pkgs + "/nixos/lib/eval-config.nix") {
    system = "aarch64-linux";
    modules = [./configuration.nix];
  }
