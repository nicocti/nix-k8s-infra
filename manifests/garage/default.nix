{config}: rec {
  name = "garage";
  version = "2.2.0";
  namespace = "garage";
  repo = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git";
  rev = "refs/tags/v${version}";
  path = "script/helm/garage";
  hash = "8NnwyiyJWGqFdTUerCV5QJq0uw8xji7HUX8sYPs5ztw=";
  # The original chart does not configure namespace, but we can't rely on Helm to add it with `helm template`
  patches = [./patches/add-namespace.patch];

  helmValues = {
    deployment.replicaCount = 4;
    garage = {
      blockSize = "1048576"; # 1MiB, can be increaed up to 10Mib
      replicationFactor = "3"; # minimum replicas for single node loss tolerance
    };
    persistence = {
      meta = {
        storageClass = "local-path";
        size = "1Gi";
      };
      data = {
        storageClass = "local-path";
        size = "100Gi";
      };
    };
    ingress.s3.api = {
      enabled = true;
      hosts = [
        {
          host = "s3.${config.domain}";
          paths = [
            {
              path = "/";
              pathType = "Prefix";
            }
          ];
        }
        {
          host = "*.s3.${config.domain}";
          paths = [
            {
              path = "/";
              pathType = "Prefix";
            }
          ];
        }
      ];
      tls = [{hosts = ["s3.${config.domain}" "*.s3.${config.domain}"];}];
    };
    image = {
      repository = "dxflrs/arm64_garage";
      tag = "v${version}";
    };
    resources = {
      limits = {
        memory = "1024Mi";
      };
      requests = {
        memory = "512Mi";
      };
    };
    commonLabels."app.${config.domain}/name" = name;
    environment = [
      {
        name = "RUST_LOG";
        value = "warn";
      }
    ];
    # Make sure only one instance per node (cannot use daemonset because we still use a PVC)
    affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [
      {
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/name" = name;
          };
        };
        topologyKey = "kubernetes.io/hostname";
      }
    ];
  };
}
