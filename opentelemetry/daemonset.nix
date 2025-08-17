{ }:
{
  name = "opentelemetry-daemonset";
  namespace = "opentelemetry";
  chart = "open-telemetry/opentelemetry-collector";
  version = "0.129.0";
  helmValues = {
    mode = "daemonset";
    image = {
      repository = "otel/opentelemetry-collector-contrib";
    };
    presets = {
      logsCollection = {
        enabled = true;
        includeCollectorLogs = false;
      };
      hostMetrics = {
        enabled = true;
      };
      kubernetesAttributes = {
        enabled = true;
        extractAllPodLabels = false;
        extractAllPodAnnotations = false;
      };
      kubeletMetrics = {
        enabled = true;
      };
    };
    resources = {
      limits = {
        memory = "512Mi";
      };
    };
    extraEnvs = [
      {
        name = "K8S_NODE_NAME";
        valueFrom = {
          fieldRef = {
            fieldPath = "spec.nodeName";
          };
        };
      }
    ];
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
          sampling_initial = 5;
          sampling_thereafter = 200;
          verbosity = "detailed";
        };
        influxdb = {
          bucket = "otel";
          endpoint = "http://influxdb.influxdb.svc.cluster.local:8181";
          timeout = "5s";
          org = "monitoring";
          token = "\${env:INFLUXDB_TOKEN}";
          span_dimensions = [
            "k8s.namespace.name"
            "k8s.node.name"
            "k8s.deployment.name"
            "k8s.pod.name"
          ];
          log_record_dimensions = [
            "k8s.namespace.name"
            "k8s.node.name"
            "k8s.deployment.name"
            "k8s.pod.name"
          ];
          metrics_schema = "telegraf-prometheus-v2";
          sending_queue = {
            enabled = true;
            num_consumers = 1;
            queue_size = 5000;
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
        "resourcedetection/k8snode" = {
          detectors = [ "k8snode" ];
        };
      };
      receivers = {
        jaeger = null;
        prometheus = null;
        zipkin = null;
        kubeletstats = {
          collection_interval = "10s";
          auth_type = "serviceAccount";
          endpoint = "\${env:K8S_NODE_NAME}:10250";
          node = "\${env:K8S_NODE_NAME}";
          k8s_api_config = {
            auth_type = "serviceAccount";
          };
          metrics = {
            "container.cpu.time" = {
              enabled = false;
            };
            "container.cpu.usage" = {
              enabled = true;
            };
            "container.cpu.utilization" = {
              enabled = false;
            };
            "container.filesystem.available" = {
              enabled = false;
            };
            "container.filesystem.capacity" = {
              enabled = false;
            };
            "container.filesystem.usage" = {
              enabled = true;
            };
            "container.memory.available" = {
              enabled = true;
            };
            "container.memory.major_page_faults" = {
              enabled = true;
            };
            "container.memory.page_faults" = {
              enabled = true;
            };
            "container.memory.rss" = {
              enabled = true;
            };
            "container.memory.usage" = {
              enabled = true;
            };
            "container.memory.working_set" = {
              enabled = true;
            };
            "container.uptime" = {
              enabled = true;
            };
            "k8s.container.cpu.node.utilization" = {
              enabled = true;
            };
            "k8s.container.cpu_limit_utilization" = {
              enabled = true;
            };
            "k8s.container.cpu_request_utilization" = {
              enabled = true;
            };
            "k8s.container.memory.node.utilization" = {
              enabled = true;
            };
            "k8s.container.memory_limit_utilization" = {
              enabled = true;
            };
            "k8s.container.memory_request_utilization" = {
              enabled = true;
            };
            "k8s.node.cpu.time" = {
              enabled = false;
            };
            "k8s.node.cpu.usage" = {
              enabled = false;
            };
            "k8s.node.cpu.utilization" = {
              enabled = false;
            };
            "k8s.node.filesystem.available" = {
              enabled = false;
            };
            "k8s.node.filesystem.capacity" = {
              enabled = false;
            };
            "k8s.node.filesystem.usage" = {
              enabled = false;
            };
            "k8s.node.memory.available" = {
              enabled = false;
            };
            "k8s.node.memory.major_page_faults" = {
              enabled = false;
            };
            "k8s.node.memory.page_faults" = {
              enabled = false;
            };
            "k8s.node.memory.rss" = {
              enabled = false;
            };
            "k8s.node.memory.usage" = {
              enabled = false;
            };
            "k8s.node.memory.working_set" = {
              enabled = false;
            };
            "k8s.node.network.errors" = {
              enabled = false;
            };
            "k8s.node.network.io" = {
              enabled = true;
            };
            "k8s.node.uptime" = {
              enabled = true;
            };
            "k8s.pod.cpu.time" = {
              enabled = false;
            };
            "k8s.pod.cpu.usage" = {
              enabled = true;
            };
            "k8s.pod.cpu.utilization" = {
              enabled = false;
            };
            "k8s.pod.cpu.node.utilization" = {
              enabled = true;
            };
            "k8s.pod.cpu_limit_utilization" = {
              enabled = true;
            };
            "k8s.pod.cpu_request_utilization" = {
              enabled = true;
            };
            "k8s.pod.filesystem.available" = {
              enabled = false;
            };
            "k8s.pod.filesystem.capacity" = {
              enabled = false;
            };
            "k8s.pod.filesystem.usage" = {
              enabled = true;
            };
            "k8s.pod.memory.available" = {
              enabled = true;
            };
            "k8s.pod.memory.major_page_faults" = {
              enabled = true;
            };
            "k8s.pod.memory.page_faults" = {
              enabled = true;
            };
            "k8s.pod.memory.rss" = {
              enabled = true;
            };
            "k8s.pod.memory.usage" = {
              enabled = true;
            };
            "k8s.pod.memory.working_set" = {
              enabled = true;
            };
            "k8s.pod.memory.node.utilization" = {
              enabled = true;
            };
            "k8s.pod.memory_limit_utilization" = {
              enabled = true;
            };
            "k8s.pod.memory_request_utilization" = {
              enabled = true;
            };
            "k8s.pod.network.errors" = {
              enabled = true;
            };
            "k8s.pod.network.io" = {
              enabled = true;
            };
            "k8s.pod.uptime" = {
              enabled = true;
            };
            "k8s.volume.available" = {
              enabled = false;
            };
            "k8s.volume.capacity" = {
              enabled = false;
            };
            "k8s.volume.inodes" = {
              enabled = false;
            };
            "k8s.volume.inodes.free" = {
              enabled = false;
            };
            "k8s.volume.inodes.used" = {
              enabled = false;
            };
          };
        };
        "hostmetrics/short" = {
          collection_interval = "10s";
          scrapers = {
            load = {
              cpu_average = true;
              metrics = {
                "system.cpu.load_average.15m" = {
                  enabled = true;
                };
                "system.cpu.load_average.5m" = {
                  enabled = true;
                };
                "system.cpu.load_average.1m" = {
                  enabled = true;
                };
              };
            };
            memory = {
              metrics = {
                "system.memory.usage" = {
                  enabled = true;
                };
                "system.memory.utilization" = {
                  enabled = true;
                };
                "system.memory.limit" = {
                  enabled = true;
                };
                "system.memory.page_size" = {
                  enabled = false;
                };
                "system.linux.memory.available" = {
                  enabled = false;
                };
                "system.linux.memory.dirty" = {
                  enabled = false;
                };
              };
            };
            network = {
              include = {
                interfaces = [ ];
              };
              metrics = {
                "system.network.connections" = {
                  enabled = false;
                };
                "system.network.dropped" = {
                  enabled = false;
                };
                "system.network.errors" = {
                  enabled = false;
                };
                "system.network.io" = {
                  enabled = false;
                };
                "system.network.packets" = {
                  enabled = false;
                };
                "system.network.conntrack.count" = {
                  enabled = false;
                };
                "system.network.conntrack.max" = {
                  enabled = false;
                };
              };
            };
            cpu = {
              metrics = {
                "system.cpu.time" = {
                  enabled = true;
                };
                "system.cpu.logical.count" = {
                  enabled = true;
                };
                "system.cpu.physical.count" = {
                  enabled = true;
                };
                "system.cpu.utilization" = {
                  enabled = true;
                };
                "system.cpu.frequency" = {
                  enabled = false;
                };
              };
            };
            disk = {
              include = {
                devices = [
                  "/dev/sda*"
                  "/dev/mapper*"
                ];
                match_type = "regexp";
              };
              metrics = {
                "system.disk.io" = {
                  enabled = true;
                };
                "system.disk.io_time" = {
                  enabled = true;
                };
                "system.disk.merged" = {
                  enabled = true;
                };
                "system.disk.operation_time" = {
                  enabled = true;
                };
                "system.disk.operations" = {
                  enabled = true;
                };
                "system.disk.pending_operations" = {
                  enabled = true;
                };
                "system.disk.weighted_io_time" = {
                  enabled = true;
                };
              };
            };
            process = {
              include = {
                names = [
                  "systemd"
                  "containerd"
                  "sshd"
                ];
                match_type = "strict";
              };
              mute_process_all_errors = true;
              mute_process_name_error = true;
              mute_process_exe_error = true;
              mute_process_io_error = true;
              mute_process_user_error = true;
              mute_process_cgroup_error = true;
              scrape_process_delay = "15s";
              metrics = {
                "process.cpu.time" = {
                  enabled = true;
                };
                "process.disk.io" = {
                  enabled = true;
                };
                "process.memory.usage" = {
                  enabled = true;
                };
                "process.memory.virtual" = {
                  enabled = true;
                };
                "process.context_switches" = {
                  enabled = true;
                };
                "process.cpu.utilization" = {
                  enabled = true;
                };
                "process.disk.operations" = {
                  enabled = true;
                };
                "process.handles" = {
                  enabled = true;
                };
                "process.memory.utilization" = {
                  enabled = true;
                };
                "process.open_file_descriptors" = {
                  enabled = true;
                };
                "process.paging.faults" = {
                  enabled = true;
                };
                "process.signals_pending" = {
                  enabled = true;
                };
                "process.threads" = {
                  enabled = true;
                };
                "process.uptime" = {
                  enabled = true;
                };
              };
            };
          };
        };
        "hostmetrics/long" = {
          collection_interval = "600s";
          scrapers = {
            system = {
              metrics = {
                "system.uptime" = {
                  enabled = true;
                };
              };
            };
            filesystem = {
              include_fs_types = {
                fs_types = [ "ext4" ];
                match_type = "strict";
              };
              include_virtual_filesystems = false;
              metrics = {
                "system.filesystem.inodes.usage" = {
                  enabled = true;
                };
                "system.filesystem.usage" = {
                  enabled = true;
                };
                "system.filesystem.utilization" = {
                  enabled = true;
                };
              };
            };
          };
        };
      };
      service = {
        extensions = [ "health_check" ];
        pipelines = {
          logs = {
            exporters = [ "influxdb" ];
            processors = [
              "memory_limiter"
              "batch"
            ];
            receivers = [
              "otlp"
              "filelog"
            ];
          };
          metrics = {
            exporters = [ "influxdb" ];
            processors = [
              "memory_limiter"
              "batch"
              "resourcedetection/k8snode"
            ];
            receivers = [
              "otlp"
              "hostmetrics/long"
              "hostmetrics/short"
              "kubeletstats"
            ];
          };
          traces = {
            exporters = [ "influxdb" ];
            processors = [
              "k8sattributes"
              "memory_limiter"
              "batch"
            ];
            receivers = [ "otlp" ];
          };
        };
        telemetry = {
          metrics = {
            address = "\${env:MY_POD_IP}:8888";
          };
        };
      };
    };
    clusterRole = {
      create = true;
      rules = [
        {
          apiGroups = [ "" ];
          resources = [
            "pod"
            "nodes"
            "nodes/proxy"
            "nodes/stats"
          ];
          verbs = [
            "get"
            "list"
            "watch"
          ];
        }
      ];
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
