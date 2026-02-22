{
  ssid ? builtins.getEnv "SSID",
  pwd ? builtins.getEnv "PASS",
  pkgs,
  ...
}: let
  config = import ./config.nix {};
  # Import Kubernetes/Helm/Nix helpers:
  kubelib = import ./lib.nix {inherit pkgs;};
  host = import ./hosts;
in rec {
  # Raspberry Pi setup:
  installer = (import ./installer {inherit ssid pwd;}).config.system.build.sdImage;
  disko = host.config.system.build.diskoScript;
  kernel = host.config.boot.kernelPackages.kernel;
  toplevel = host.config.system.build.toplevel;

  # Load configuration of our Kubernetes applications:
  conf = {
    garage = import ./garage {inherit config;};
    grafana = import ./grafana {inherit config;};
    influxdb = import ./influxdb {inherit config;};
    cilium = import ./cilium {inherit config;};
    opentelemetry-daemonset = import ./opentelemetry/daemonset.nix {};
    opentelemetry-deployment = import ./opentelemetry/deployment.nix {};
  };

  # Get charts as Nix derivations:
  charts = builtins.mapAttrs (name: value: kubelib.pullHelmChart value) conf;

  # Get generated manifests as Nix derivations:
  manifests =
    builtins.mapAttrs (
      name: value: kubelib.buildManifests (value // {chart = charts.${name};})
    )
    conf;
}
