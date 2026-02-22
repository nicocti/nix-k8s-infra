{config}: rec {
  namespace = "influxdb";
  name = "influxdb";
  version = "3.8.0";
  bucket = {
    name = "influxdb";
    secret = "garage-creds";
  };
  extraManifests = [
    {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = name;
        namespace = namespace;
        labels = {
          "app.kubernetes.io/name" = "influxdb3-enterprise";
          "app.kubernetes.io/instance" = "influxdb";
          "app.kubernetes.io/version" = version;
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
            volumes = [
              {
                name = "admin-token";
                secret = {
                  secretName = "admin-token";
                  defaultMode = 384; # "0600";
                };
              }
            ];
            containers = [
              {
                name = name;
                image = "influxdb:${version}-enterprise";
                command = [
                  "influxdb3"
                  "serve"
                  "--mode=all"
                  "--object-store=s3"
                  "--cluster-id=cluster0"
                  "--node-id=node0"
                  "--admin-token-file=/run/secrets/admin-token/admin-token"
                ];
                volumeMounts = [
                  {
                    name = "admin-token";
                    mountPath = "/run/secrets/admin-token/";
                    readOnly = true;
                  }
                ];
                ports = [
                  {
                    containerPort = 8181;
                    name = "http";
                    protocol = "TCP";
                  }
                ];
                readinessProbe = {
                  failureThreshold = 3;
                  httpGet = {
                    path = "/health";
                    port = "http";
                    scheme = "HTTP";
                  };
                  periodSeconds = 5;
                  successThreshold = 1;
                  timeoutSeconds = 3;
                };
                livenessProbe = {
                  failureThreshold = 3;
                  httpGet = {
                    path = "/health";
                    port = "http";
                    scheme = "HTTP";
                  };
                  periodSeconds = 10;
                  successThreshold = 1;
                  timeoutSeconds = 5;
                };
                startupProbe = {
                  failureThreshold = 12;
                  httpGet = {
                    path = "/health";
                    port = "http";
                    scheme = "HTTP";
                  };
                  initialDelaySeconds = 10;
                  periodSeconds = 5;
                  successThreshold = 1;
                  timeoutSeconds = 5;
                };
                env = [
                  {
                    name = "INFLUXDB3_ENTERPRISE_LICENSE_EMAIL";
                    value = "${config.influxdb.email}";
                  }
                  {
                    name = "INFLUXDB3_ENTERPRISE_LICENSE_TYPE";
                    value = "home";
                  }
                  {
                    name = "INFLUXDB3_BUCKET";
                    value = bucket.name;
                  }
                  {
                    name = "INFLUXDB3_DISABLE_AUTHZ";
                    value = "health";
                  }
                  {
                    name = "AWS_ACCESS_KEY_ID";
                    valueFrom = {
                      secretKeyRef = {
                        name = bucket.secret;
                        key = "access-key-id";
                      };
                    };
                  }
                  {
                    name = "AWS_SECRET_ACCESS_KEY";
                    valueFrom = {
                      secretKeyRef = {
                        name = bucket.secret;
                        key = "secret-access-key";
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
                    value = "info";
                  }
                ];
              }
            ];
            securityContext = {
              fsGroup = 1500;
              runAsGroup = 1500;
              runAsNonRoot = true;
              runAsUser = 1500;
            };
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
        labels = {
          "app.kubernetes.io/name" = "influxdb3-enterprise";
          "app.kubernetes.io/instance" = "influxdb";
          "app.kubernetes.io/version" = version;
        };
      };
      spec = {
        selector = {
          "app.kubernetes.io/name" = "influxdb3-enterprise";
        };
        ports = [
          {
            name = "http";
            port = 8181;
            protocol = "TCP";
            targetPort = "http";
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
        labels = {
          "app.kubernetes.io/name" = "influxdb3-enterprise";
          "app.kubernetes.io/instance" = "influxdb";
          "app.kubernetes.io/version" = version;
        };
      };
      spec = {
        ingressClassName = "cilium";
        rules = [
          {
            host = "influxdb.${config.domain}";
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
                  path = "/api/v3/query";
                  pathType = "Prefix";
                }
                {
                  backend = {
                    service = {
                      name = name;
                      port = {
                        number = 8181;
                      };
                    };
                  };
                  path = "/query";
                  pathType = "Prefix";
                }
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
                {
                  backend = {
                    service = {
                      name = name;
                      port = {
                        number = 8181;
                      };
                    };
                  };
                  path = "/api/v3/write_lp";
                  pathType = "Prefix";
                }
                {
                  backend = {
                    service = {
                      name = name;
                      port = {
                        number = 8181;
                      };
                    };
                  };
                  path = "/api/v2/write";
                  pathType = "Prefix";
                }
                {
                  backend = {
                    service = {
                      name = name;
                      port = {
                        number = 8181;
                      };
                    };
                  };
                  path = "/write";
                  pathType = "Prefix";
                }
              ];
            };
          }
        ];
        tls = [{hosts = ["influxdb.${config.domain}"];}];
      };
    }
  ];
}
