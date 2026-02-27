{config}: rec {
  name = "grafana";
  version = "11.2.1";
  namespace = "grafana";
  url = "https://github.com/grafana-community/helm-charts/releases/download/grafana-${version}/grafana-${version}.tgz";
  hash = "0qy31ym4mk2ilwhlqfafrf93j2vhz8306fv4nfss0fj3gpa59fbv";

  helmValues = {
    replicas = 1;
    headlessService = false;
    createConfigmap = true;
    persistence.enabled = false;
    testFramework.enabled = false;
    sidecar.logLevel = "WARN";

    ingress = {
      enabled = true;
      hosts = ["grafana.${config.domain}"];
      tls = [{hosts = ["grafana.${config.domain}"];}];
    };

    admin = {
      existingSecret = "grafana-auth";
      userKey = "admin-user";
      passwordKey = "admin-password";
    };

    envFromSecrets = [{name = "influx-auth";}];
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
        deleteDatasources = [{name = "Prometheus";}];
      };
    };
    "grafana.ini" = {
      analytics.check_for_updates = false;
      log = {
        mode = "console";
        level = "warn";
      };
    };
  };
}
