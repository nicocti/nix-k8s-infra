{
  config,
}:
{
  name = "grafana";
  chart = "grafana";
  namespace = "grafana";
  repo = "https://grafana.github.io/helm-charts/";
  version = "10.1.2";
  hash = "sha256-++ZBsLLr2ICie6qs0YfBHYLbO/BWuUn3Cws3JZRv6hU=";

  helmValues = {
    replicas = 1;
    headlessService = false;
    createConfigmap = true;
    ingress = {
      enabled = true;
      hosts = [ "grafana.${config.domain}" ];
      tls = [ { hosts = [ "grafana.${config.domain}" ]; } ];
    };
    persistence = {
      enabled = false;
    };
    admin = {
      existingSecret = "grafana-auth";
      userKey = "admin-user";
      passwordKey = "admin-password";
    };
    envFromSecrets = [ { name = "influx-auth"; } ];
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1;
        datasources = [
          {
            name = "InfluxDB";
            type = "influxdb";
            access = "proxy";
            url = "http://influxdb.influxdb.svc.cluster.local:8181";
            jsonData = {
              version = "SQL";
              dbName = "otel";
              httpMode = "POST";
              insecureGrpc = true;
            };
            secureJsonData = {
              token = "\${INFLUXDB_TOKEN}";
            };
          }
        ];
        deleteDatasources = [ { name = "Prometheus"; } ];
      };
    };
    "grafana.ini" = {
      analytics = {
        check_for_updates = false;
      };
      log = {
        mode = "console";
        level = "warn";
      };
    };
    sidecar = {
      logLevel = "WARN";
    };
    testFramework = {
      enabled = false;
    };
  };
}
