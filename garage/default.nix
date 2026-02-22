{config}: {
  name = "garage";
  namespace = "garage";
  repo = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git";
  rev = "refs/tags/v2.2.0";
  path = "script/helm/garage";
  hash = "sha256-8NnwyiyJWGqFdTUerCV5QJq0uw8xji7HUX8sYPs5ztw=";
  patches = [./patches/add-namespace.patch];
  version = "2.2.0";

  helmValues = {
    commonLabels = {
      "app.${config.domain}/name" = "garage";
    };
    garage = {
      blockSize = "1048576"; # 1MiB, can be increaed up to 10Mib
      replicationFactor = "3"; # minimum replicas for single node loss tolerance
    };
    deployment = {
      replicaCount = 4;
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
    ingress = {
      s3 = {
        api = {
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
      };
    };
    image = {
      repository = "dxflrs/arm64_garage";
      tag = "v2.2.0";
    };
    resources = {
      limits = {
        memory = "1024Mi";
      };
      requests = {
        memory = "512Mi";
      };
    };
    environment = [
      {
        name = "RUST_LOG";
        value = "warn";
      }
    ];
    affinity = {
      podAntiAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = [
          {
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name" = "garage";
              };
            };
            topologyKey = "kubernetes.io/hostname";
          }
        ];
      };
    };
  };
}
