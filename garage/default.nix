{
  domain,
}:
{
  name = "garage";
  namespace = "garage";
  repo = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git";
  rev = "refs/tags/v1.2.0";
  path = "script/helm/garage";
  hash = "sha256-lstBIYXzlIl9If2l6deNmhN3/QjmOpnu7zvQbsW1XdU=";
  version = "1.2.0";

  helmValues = {
    garage = {
      replicationMode = "2";
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
              host = "s3.${domain}";
              paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                }
              ];
            }
          ];
          tls = [ { hosts = [ "s3.${domain}" ]; } ];
        };
      };
    };
    image = {
      repository = "dxflrs/arm64_garage";
      tag = "v1.1.0";
    };
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
    environment = [
      {
        name = "RUST_LOG";
        value = "warn";
      }
    ];
  };
}
