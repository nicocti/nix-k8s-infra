{ }:
{
  name = "opentelemetry-deployment";
  chart = "opentelemetry-collector";
  namespace = "otel";
  repo = "https://open-telemetry.github.io/opentelemetry-helm-charts";
  hash = "sha256-Tq49zjTKEIvm28F/7b8Y3cGX7/J9/fJjJdN+i21FNVk=";
  version = "0.129.0";

  helmValues = {
    mode = "deployment";
    image = {
      repository = "otel/opentelemetry-collector-contrib";
    };
    replicaCount = 1;
    revisionHistoryLimit = 10;
    presets = {
      kubernetesEvents = {
        enabled = true;
      };
      clusterMetrics = {
        enabled = true;
      };
    };
    resources = {
      limits = {
        memory = "512Mi";
      };
    };
    configMap = {
      create = true;
    };
    extraEnvsFrom = [
      {
        secretRef = {
          name = "influx-auth";
        };
      }
    ];
    config = {
      exporters = {
        debug = {
          verbosity = "basic";
          sampling_initial = 5;
          sampling_thereafter = 200;
        };
        influxdb = {
          bucket = "otel";
          endpoint = "http://influxdb.influxdb.svc.cluster.local:8181";
          timeout = "5s";
          org = "monitoring";
          token = "\${env:INFLUXDB_TOKEN}";
          span_dimensions = [
            "service.name"
            "span.name"
          ];
          log_record_dimensions = [ "service.name" ];
          metrics_schema = "telegraf-prometheus-v2";
          sending_queue = {
            enabled = true;
            num_consumers = 3;
            queue_size = 10;
          };
          retry_on_failure = {
            enabled = true;
            initial_interval = "1s";
            max_interval = "3s";
            max_elapsed_time = "10s";
          };
        };
      };
      extensions = {
        health_check = {
          endpoint = "\${env:MY_POD_IP}:13133";
        };
      };
      processors = {
        batch = { };
        memory_limiter = {
          check_interval = "5s";
          limit_percentage = 80;
          spike_limit_percentage = 25;
        };
      };
      receivers = {
        jaeger = null;
        prometheus = null;
        zipkin = null;
        otlp = {
          protocols = {
            grpc = {
              endpoint = "\${env:MY_POD_IP}:4317";
            };
            http = {
              endpoint = "\${env:MY_POD_IP}:4318";
            };
          };
        };
      };
      service = {
        telemetry = {
          metrics = {
            address = "\${env:MY_POD_IP}:8888";
          };
        };
        extensions = [ "health_check" ];
        pipelines = {
          logs = {
            exporters = [ "influxdb" ];
            processors = [
              "memory_limiter"
              "batch"
            ];
            receivers = [ "otlp" ];
          };
          metrics = {
            exporters = [ "influxdb" ];
            processors = [
              "memory_limiter"
              "batch"
            ];
            receivers = [ "otlp" ];
          };
          traces = {
            exporters = [ "influxdb" ];
            processors = [
              "memory_limiter"
              "batch"
            ];
            receivers = [ "otlp" ];
          };
        };
      };
    };
    clusterRole = {
      create = true;
    };
    ports = {
      metrics = {
        enabled = true;
      };
      jaeger-compact = {
        enabled = false;
      };
      jaeger-thrift = {
        enabled = false;
      };
      jaeger-grpc = {
        enabled = false;
      };
      zipkin = {
        enabled = false;
      };
    };
  };
}
