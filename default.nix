{
  pkgs,
  ...
}@args:
rec {
  # Import Kubernetes/Helm/Nix helpers:
  kubelib = import ./lib { inherit pkgs; };

  # Load configuration of our Kubernetes applications:
  conf = {
    garage = import ./garage { inherit (args) domain; };
    grafana = import ./grafana { inherit (args) domain; };
    influxdb = import ./influxdb { inherit (args) domain email; };
    cilium = import ./cilium {
      inherit (args)
        domain
        rproxyIp
        k8sApiAddr
        ipPoolStart
        ipPoolStop
        ;
    };
  };

  # Get chart as Nix derivations:
  charts = builtins.mapAttrs (name: value: kubelib.pullHelmChart value) conf;

  # Get generated manifests as Nix derivations:
  manifests = builtins.mapAttrs (
    name: value: kubelib.buildManifests (value // { chart = (builtins.getAttr name charts); })
  ) conf;

}
