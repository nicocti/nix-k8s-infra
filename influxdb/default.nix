{
  domain,
  email,
}:
rec {
  namespace = "influxdb";
  name = "influxdb";
  version = "3.3";

  extraManifests = [
    {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = name;
        namespace = namespace;
        labels = {
          "app.kubernetes.io/name" = name;
        };
      };
      spec = {
        replicas = 1;
        selector = {
          matchLabels = {
            "app.kubernetes.io/name" = name;
          };
        };
        template = {
          metadata = {
            labels = {
              "app.kubernetes.io/name" = name;
            };
          };
          spec = {
            containers = [
              {
                name = name;
                image = "influxdb:3.3-enterprise";
                command = [
                  "influxdb3"
                  "serve"
                  "--cluster-id=cluster0"
                  "--node-id=node0"
                ];
                ports = [ { containerPort = 8181; } ];
                env = [
                  {
                    name = "INFLUXDB3_ENTERPRISE_LICENSE_EMAIL";
                    value = "${email}";
                  }
                  {
                    name = "INFLUXDB3_OBJECT_STORE";
                    value = "s3";
                  }
                  {
                    name = "INFLUXDB3_BUCKET";
                    value = "influxdb";
                  }
                  {
                    name = "AWS_ACCESS_KEY_ID";
                    valueFrom = {
                      secretKeyRef = {
                        name = "s3-influxdb";
                        key = "AWS_ACCESS_KEY_ID";
                      };
                    };
                  }
                  {
                    name = "AWS_SECRET_ACCESS_KEY";
                    valueFrom = {
                      secretKeyRef = {
                        name = "s3-influxdb";
                        key = "AWS_SECRET_ACCESS_KEY";
                      };
                    };
                  }
                  {
                    name = "AWS_DEFAULT_REGION";
                    value = "garage";
                  }
                  {
                    name = "AWS_ENDPOINT";
                    value = "http://garage.garage.svc.cluster.local:3900";
                  }
                  {
                    name = "AWS_ALLOW_HTTP";
                    value = "true";
                  }
                  {
                    name = "LOG_FILTER";
                    value = "warn";
                  }
                ];
              }
            ];
          };
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = name;
        namespace = namespace;
      };
      spec = {
        selector = {
          "app.kubernetes.io/name" = name;
        };
        ports = [
          {
            protocol = "TCP";
            port = 8181;
            targetPort = 8181;
          }
        ];
      };
    }
    {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata = {
        name = "influxdb-api";
        namespace = namespace;
      };
      spec = {
        ingressClassName = "cilium";
        rules = [
          {
            host = "influxdb.${domain}";
            http = {
              paths = [
                {
                  backend = {
                    service = {
                      name = name;
                      port = {
                        number = 8181;
                      };
                    };
                  };
                  path = "/";
                  pathType = "Prefix";
                }
              ];
            };
          }
        ];
        tls = [ { hosts = [ "influxdb.${domain}" ]; } ];
      };
    }
  ];
}
