{
  ssid ? builtins.getEnv "SSID",
  pwd ? builtins.getEnv "PASS",
  pkgs,
  lib ? pkgs.lib,
  ...
}: let
  config = import ./config.nix {};
  kubelib = import ./lib.nix {inherit pkgs;};
  host = import ./hosts;
  manifestsDir = ./manifests;
in rec {
  # Raspberry Pi setup:
  installer = (import ./installer {inherit ssid pwd;}).config.system.build.sdImage;
  disko = host.config.system.build.diskoScript;
  kernel = host.config.boot.kernelPackages.kernel;
  toplevel = host.config.system.build.toplevel;

  # Load configuration of our Kubernetes applications:
  configs = lib.mapAttrs (
    name: _type: import (manifestsDir + "/${name}") {inherit config;}
  ) (builtins.readDir manifestsDir);

  # Get charts as Nix derivations:
  charts = builtins.mapAttrs (name: value: kubelib.pullHelmChart value) configs;

  # Get generated manifests as Nix derivations:
  manifests =
    builtins.mapAttrs (
      name: value: kubelib.buildManifests (value // {chart = charts.${name};})
    )
    configs;
}
