{config, ...}: rec {
  name = "opentelemetry";
  namespace = "otel";
  version = "0.106.0";
  url = "https://github.com/open-telemetry/opentelemetry-helm-charts/releases/download/opentelemetry-operator-${version}/opentelemetry-operator-${version}.tgz";
  hash = "05k57n3rkwf1yrzzwp0cp19l3vnq8l2117gpgckzn8364djwicgw";

  helmValues = {
    replicaCount = 1;
    revisionHistoryLimit = 10;
    admissionWebhooks.certManager.enabled = false;
    kubeRBACProxy.enabled = false;
    manager = {
      createRbacPermissions = false;
      leaderElection.enabled = false;
      collectorImage = {
        repository = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib";
        tag = "0.145.0";
      };
      autoInstrumentation.go.enabled = true;
      extraEnvs = [
        {
          name = "GOMEMLIMIT";
          valueFrom = {
            resourceFieldRef = {
              containerName = "manager";
              resource = "limits.memory";
            };
          };
        }
      ];
      resources = {
        limits = {
          memory = "128Mi";
          ephemeral-storage = "50Mi";
        };
        requests = {
          memory = "64Mi";
          ephemeral-storage = "50Mi";
        };
      };
    };
  };
  extraManifests = [
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata = {
        labels = {
          "app.kubernetes.io/component" = "opentelemetry-collector";
          "app.kubernetes.io/instance" = "otel.daemonset";
          "app.kubernetes.io/name" = "daemonset-otel-cluster-role";
          "app.kubernetes.io/part-of" = "opentelemetry";
        };
        name = "daemonset-otel-cluster-role";
      };
      rules = [
        {
          apiGroups = [""];
          resources = ["nodes/stats" "nodes/proxy"];
          verbs = ["get"];
        }
        {
          apiGroups = [""];
          resources = ["pods" "namespaces" "nodes"];
          verbs = ["get" "watch" "list"];
        }
        {
          apiGroups = ["apps"];
          resources = ["replicasets" "deployments" "statefulsets" "daemonsets"];
          verbs = ["get" "watch" "list"];
        }
        {
          apiGroups = ["batch"];
          resources = ["jobs" "cronjobs"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["extensions"];
          resources = ["daemonsets" "deployments" "replicasets"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = [""];
          resources = ["persistentvolumeclaims" "persistentvolumes"];
          verbs = ["get" "list"];
        }
      ];
    }
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata = {
        labels = {
          "app.kubernetes.io/component" = "opentelemetry-collector";
          "app.kubernetes.io/instance" = "otel.daemonset";
          "app.kubernetes.io/name" = "daemonset-otel-collector";
          "app.kubernetes.io/part-of" = "opentelemetry";
        };
        name = "daemonset-otel-collector";
      };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "daemonset-otel-cluster-role";
      };
      subjects = [
        {
          kind = "ServiceAccount";
          name = "daemonset-collector";
          namespace = "otel";
        }
      ];
    }
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata = {
        labels = {
          "app.kubernetes.io/name" = "deployment-otel-cluster-role";
          "app.kubernetes.io/component" = "opentelemetry-collector";
          "app.kubernetes.io/instance" = "otel.deployment";
          "app.kubernetes.io/part-of" = "opentelemetry";
        };
        name = "deployment-otel-cluster-role";
      };
      rules = [
        {
          apiGroups = [""];
          resources = ["events" "namespaces" "namespaces/status" "nodes" "nodes/spec" "pods" "pods/status" "replicationcontrollers" "replicationcontrollers/status" "resourcequotas" "services"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["apps"];
          resources = ["daemonsets" "deployments" "replicasets" "statefulsets"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["extensions"];
          resources = ["daemonsets" "deployments" "replicasets"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["batch"];
          resources = ["jobs" "cronjobs"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["autoscaling"];
          resources = ["horizontalpodautoscalers"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["events.k8s.io"];
          resources = ["events"];
          verbs = ["list" "watch"];
        }
      ];
    }
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata = {
        labels = {
          "app.kubernetes.io/component" = "opentelemetry-collector";
          "app.kubernetes.io/instance" = "otel.deployment";
          "app.kubernetes.io/name" = "deployment-otel-collector";
          "app.kubernetes.io/part-of" = "opentelemetry";
        };
        name = "deployment-otel-collector";
      };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "deployment-otel-cluster-role";
      };
      subjects = [
        {
          kind = "ServiceAccount";
          name = "deployment-collector";
          namespace = "otel";
        }
      ];
    }
    {
      apiVersion = "opentelemetry.io/v1beta1";
      kind = "OpenTelemetryCollector";
      metadata = {
        name = "daemonset";
        namespace = namespace;
      };
      spec = {
        mode = "daemonset";
        terminationGracePeriodSeconds = 100;
        hostNetwork = false;
        hostPID = true;
        resources = {
          limits = {
            memory = "500Mi";
          };
          requests = {
            memory = "250Mi";
          };
        };
        env = [
          {
            name = "K8S_NODE_NAME";
            valueFrom.fieldRef.fieldPath = "spec.nodeName";
          }
          {
            name = "K8S_NODE_IP";
            valueFrom.fieldRef.fieldPath = "status.hostIP";
          }
          {
            name = "K8S_NAMESPACE";
            valueFrom = {
              fieldRef = {
                apiVersion = "v1";
                fieldPath = "metadata.namespace";
              };
            };
          }
          {
            name = "K8S_POD_NAME";
            valueFrom = {
              fieldRef = {
                apiVersion = "v1";
                fieldPath = "metadata.name";
              };
            };
          }
          {
            name = "K8S_POD_IP";
            valueFrom = {
              fieldRef = {
                apiVersion = "v1";
                fieldPath = "status.podIP";
              };
            };
          }
          {
            name = "OTEL_RESOURCE_ATTRIBUTES"; # parsed by resourcedetection/env detector
            value = "k8s.pod.name=$(K8S_POD_NAME),k8s.namespace.name=$(K8S_NAMESPACE),k8s.node.name=$(K8S_NODE_NAME),k8s.node.ip=$(K8S_NODE_IP),k8s.pod.ip=$(K8S_POD_IP)";
          }
        ];
        envFrom = [
          {
            secretRef = {
              name = "influx-auth";
            };
          }
        ];
        volumeMounts = [
          {
            mountPath = "/var/log/pods";
            name = "varlogpods";
            readOnly = true;
          }
          {
            mountPath = "/var/lib/docker/containers";
            name = "varlibdockercontainers";
            readOnly = true;
          }
          {
            mountPath = "/hostfs";
            mountPropagation = "HostToContainer";
            name = "hostfs";
            readOnly = true;
          }
        ];
        volumes = [
          {
            hostPath = {path = "/var/log/pods";};
            name = "varlogpods";
          }
          {
            hostPath = {path = "/var/lib/docker/containers";};
            name = "varlibdockercontainers";
          }
          {
            hostPath = {path = "/";};
            name = "hostfs";
          }
        ];
        config = {
          receivers = {
            filelog = {
              exclude = ["/var/log/pods/${namespace}_daemonset*_*/otc-container/*.log"];
              include = ["/var/log/pods/*/*/*.log"];
              include_file_name = false;
              include_file_path = true;
              operators = [
                {
                  id = "container-parser";
                  max_log_size = 102400;
                  type = "container";
                }
              ];
              retry_on_failure = {enabled = true;};
              start_at = "end";
            };
            "hostmetrics/short" = {
              collection_interval = "10s";
              root_path = "/hostfs";
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
                    interfaces = [];
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
                paging = {metrics = {"system.paging.usage" = {enabled = true;};};};
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
              root_path = "/hostfs";
              scrapers = {
                system = {
                  metrics = {
                    "system.uptime" = {
                      enabled = true;
                    };
                  };
                };
                filesystem = {
                  exclude_fs_types = {
                    fs_types = [
                      "autofs"
                      "binfmt_misc"
                      "bpf"
                      "cgroup2"
                      "configfs"
                      "debugfs"
                      "devpts"
                      "devtmpfs"
                      "fusectl"
                      "hugetlbfs"
                      "iso9660"
                      "mqueue"
                      "nsfs"
                      "overlay"
                      "proc"
                      "procfs"
                      "pstore"
                      "rpc_pipefs"
                      "securityfs"
                      "selinuxfs"
                      "squashfs"
                      "sysfs"
                      "tracefs"
                    ];
                    match_type = "strict";
                  };
                  exclude_mount_points = {
                    match_type = "regexp";
                    mount_points = [
                      "/boot/firm*"
                      "/dev/*"
                      "/proc/*"
                      "/sys/*"
                      "/run/k3s/containerd/*"
                      "/var/lib/docker/*"
                      "/var/lib/kubelet/*"
                      "/snap/*"
                    ];
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
            kubeletstats = {
              auth_type = "serviceAccount";
              collection_interval = "15s";
              insecure_skip_verify = true;
              endpoint = "https://\${env:K8S_NODE_IP}:10250";
              k8s_api_config = {auth_type = "serviceAccount";};
              extra_metadata_labels = ["container.id" "k8s.volume.type"];
              metric_groups = ["node" "pod" "volume" "container"];
              metrics = {
                "container.cpu.time" = {enabled = false;};
                "container.cpu.usage" = {enabled = true;};
                "container.filesystem.available" = {enabled = false;};
                "container.filesystem.capacity" = {enabled = false;};
                "container.filesystem.usage" = {enabled = true;};
                "container.memory.available" = {enabled = true;};
                "container.memory.major_page_faults" = {enabled = true;};
                "container.memory.page_faults" = {enabled = true;};
                "container.memory.rss" = {enabled = true;};
                "container.memory.usage" = {enabled = true;};
                "container.memory.working_set" = {enabled = true;};
                "container.uptime" = {enabled = true;};
                "k8s.container.cpu.node.utilization" = {enabled = true;};
                "k8s.container.cpu_limit_utilization" = {enabled = true;};
                "k8s.container.cpu_request_utilization" = {enabled = true;};
                "k8s.container.memory.node.utilization" = {enabled = true;};
                "k8s.container.memory_limit_utilization" = {enabled = true;};
                "k8s.container.memory_request_utilization" = {enabled = true;};
                "k8s.node.cpu.time" = {enabled = false;};
                "k8s.node.cpu.usage" = {enabled = false;};
                "k8s.node.filesystem.available" = {enabled = false;};
                "k8s.node.filesystem.capacity" = {enabled = false;};
                "k8s.node.filesystem.usage" = {enabled = false;};
                "k8s.node.memory.available" = {enabled = false;};
                "k8s.node.memory.major_page_faults" = {enabled = false;};
                "k8s.node.memory.page_faults" = {enabled = false;};
                "k8s.node.memory.rss" = {enabled = false;};
                "k8s.node.memory.usage" = {enabled = false;};
                "k8s.node.memory.working_set" = {enabled = false;};
                "k8s.node.network.errors" = {enabled = false;};
                "k8s.node.network.io" = {enabled = true;};
                "k8s.node.uptime" = {enabled = true;};
                "k8s.pod.cpu.node.utilization" = {enabled = true;};
                "k8s.pod.cpu.time" = {enabled = false;};
                "k8s.pod.cpu.usage" = {enabled = true;};
                "k8s.pod.cpu_limit_utilization" = {enabled = true;};
                "k8s.pod.cpu_request_utilization" = {enabled = true;};
                "k8s.pod.filesystem.available" = {enabled = false;};
                "k8s.pod.filesystem.capacity" = {enabled = false;};
                "k8s.pod.filesystem.usage" = {enabled = true;};
                "k8s.pod.memory.available" = {enabled = true;};
                "k8s.pod.memory.major_page_faults" = {enabled = true;};
                "k8s.pod.memory.node.utilization" = {enabled = true;};
                "k8s.pod.memory.page_faults" = {enabled = true;};
                "k8s.pod.memory.rss" = {enabled = true;};
                "k8s.pod.memory.usage" = {enabled = true;};
                "k8s.pod.memory.working_set" = {enabled = true;};
                "k8s.pod.memory_limit_utilization" = {enabled = true;};
                "k8s.pod.memory_request_utilization" = {enabled = true;};
                "k8s.pod.network.errors" = {enabled = true;};
                "k8s.pod.network.io" = {enabled = true;};
                "k8s.pod.uptime" = {enabled = true;};
                "k8s.volume.available" = {enabled = false;};
                "k8s.volume.capacity" = {enabled = false;};
                "k8s.volume.inodes" = {enabled = false;};
                "k8s.volume.inodes.free" = {enabled = false;};
                "k8s.volume.inodes.used" = {enabled = false;};
              };
              node = "\${env:K8S_NODE_NAME}";
            };
            otlp = {
              protocols = {
                grpc = {endpoint = "\${env:K8S_POD_IP}:4317";};
                http = {endpoint = "\${env:K8S_POD_IP}:4318";};
              };
            };
          };
          exporters = {
            debug = {
              sampling_initial = 5;
              sampling_thereafter = 200;
              verbosity = "detailed";
            };
            influxdb = {
              bucket = "otel";
              endpoint = "http://influxdb.influxdb.svc.cluster.local:8181";
              log_record_dimensions = ["service.namespace" "service.name" "service.instance.id" "host.name"];
              metrics_schema = "telegraf-prometheus-v2";
              org = "monitoring";
              retry_on_failure = {
                enabled = true;
                initial_interval = "1s";
                max_elapsed_time = "10s";
                max_interval = "3s";
              };
              sending_queue = {
                enabled = true;
                num_consumers = 1;
                queue_size = 5000;
              };
              span_dimensions = ["service.namespace" "service.name" "service.instance.id" "host.name" "span.name"];
              timeout = "5s";
              token = "\${env:INFLUXDB_TOKEN}";
            };
          };
          processors = {
            batch = {
              send_batch_max_size = 1500;
              send_batch_size = 1000;
              timeout = "1s";
            };
            k8sattributes = {
              extract = {
                labels = [
                  {
                    from = "pod";
                    key = "app.kubernetes.io/name";
                    tag_name = "k8s.app.name";
                  }
                  {
                    from = "pod";
                    key = "app.kubernetes.io/instance";
                    tag_name = "k8s.app.instance";
                  }
                  {
                    from = "pod";
                    key = "app.kubernetes.io/component";
                    tag_name = "k8s.app.component";
                  }
                ];
                metadata = [
                  "k8s.namespace.name"
                  "k8s.pod.name"
                  "k8s.pod.uid"
                  "k8s.node.name"
                  "k8s.pod.start_time"
                  "k8s.deployment.name"
                  "k8s.replicaset.name"
                  "k8s.replicaset.uid"
                  "k8s.daemonset.name"
                  "k8s.daemonset.uid"
                  "k8s.job.name"
                  "k8s.job.uid"
                  "k8s.container.name"
                  "k8s.cronjob.name"
                  "k8s.statefulset.name"
                  "k8s.statefulset.uid"
                  "container.image.tag"
                  "container.image.name"
                  "k8s.cluster.uid"
                  "service.namespace"
                  "service.name"
                  "service.version"
                  "service.instance.id"
                ];
                otel_annotations = true;
              };
              filter = {node_from_env_var = "K8S_NODE_NAME";};
              passthrough = false;
              pod_association = [
                {
                  sources = [
                    {
                      from = "resource_attribute";
                      name = "k8s.pod.uid";
                    }
                  ];
                }
                {
                  sources = [
                    {
                      from = "resource_attribute";
                      name = "k8s.pod.name";
                    }
                    {
                      from = "resource_attribute";
                      name = "k8s.namespace.name";
                    }
                    {
                      from = "resource_attribute";
                      name = "k8s.node.name";
                    }
                  ];
                }
                {
                  sources = [
                    {
                      from = "resource_attribute";
                      name = "k8s.pod.ip";
                    }
                  ];
                }
                {
                  sources = [
                    {
                      from = "resource_attribute";
                      name = "k8s.pod.name";
                    }
                    {
                      from = "resource_attribute";
                      name = "k8s.namespace.name";
                    }
                  ];
                }
                {sources = [{from = "connection";}];}
              ];
            };
            memory_limiter = {
              check_interval = "5s";
              limit_percentage = 80;
              spike_limit_percentage = 25;
            };
            "resource/hostname" = {
              attributes = [
                {
                  action = "insert";
                  from_attribute = "k8s.node.name";
                  key = "host.name";
                }
              ];
            };
            # Used when k8sattributes cannot help:
            "resourcedetection/env" = {
              detectors = ["env" "k8snode"];
              override = false;
              timeout = "2s";
            };
          };
          service = {
            pipelines = {
              logs = {
                receivers = ["otlp" "filelog"];
                processors = ["memory_limiter" "k8sattributes" "resourcedetection/env" "resource/hostname" "batch"];
                exporters = ["influxdb"];
              };
              metrics = {
                receivers = ["otlp" "hostmetrics/long" "hostmetrics/short" "kubeletstats"];
                processors = ["memory_limiter" "k8sattributes" "resourcedetection/env" "resource/hostname" "batch"];
                exporters = ["influxdb"];
              };
              traces = {
                receivers = ["otlp"];
                processors = ["memory_limiter" "k8sattributes" "resourcedetection/env" "resource/hostname" "batch"];
                exporters = ["influxdb"];
              };
            };
          };
        };
      };
    }
    {
      apiVersion = "opentelemetry.io/v1beta1";
      kind = "OpenTelemetryCollector";
      metadata = {
        name = "deployment";
        namespace = namespace;
      };
      spec = {
        mode = "deployment";
        replicas = 1;
        terminationGracePeriodSeconds = 100;
        hostNetwork = false;
        hostPID = false;
        resources = {
          limits = {
            memory = "500Mi";
          };
          requests = {
            memory = "250Mi";
          };
        };
        envFrom = [
          {
            secretRef = {
              name = "influx-auth";
            };
          }
        ];
        env = [
          {
            name = "K8S_POD_IP";
            valueFrom = {
              fieldRef = {
                apiVersion = "v1";
                fieldPath = "status.podIP";
              };
            };
          }
        ];
        config = {
          exporters = {
            debug = {
              sampling_initial = 5;
              sampling_thereafter = 200;
              verbosity = "basic";
            };
            influxdb = {
              bucket = "otel";
              endpoint = "http://influxdb.influxdb.svc.cluster.local:8181";
              log_record_dimensions = ["service.namespace" "service.name" "service.instance.id" "host.name"];
              metrics_schema = "telegraf-prometheus-v2";
              org = "monitoring";
              retry_on_failure = {
                enabled = true;
                initial_interval = "1s";
                max_elapsed_time = "10s";
                max_interval = "3s";
              };
              sending_queue = {
                enabled = true;
                num_consumers = 3;
                queue_size = 10;
              };
              span_dimensions = ["service.namespace" "service.name" "service.instance.id" "host.name" "span.name"];
              timeout = "5s";
              token = "\${env:INFLUXDB_TOKEN}";
            };
          };
          processors = {
            batch = {
              send_batch_max_size = 1500;
              send_batch_size = 1000;
              timeout = "1s";
            };
            memory_limiter = {
              check_interval = "5s";
              limit_percentage = 80;
              spike_limit_percentage = 25;
            };
          };
          receivers = {
            k8s_cluster = {
              allocatable_types_to_report = ["cpu" "memory" "storage"];
              auth_type = "serviceAccount";
              collection_interval = "10s";
              node_conditions_to_report = ["Ready" "MemoryPressure" "DiskPressure" "NetworkUnavailable"];
            };
            k8sobjects = {
              objects = [
                {
                  exclude_watch_type = ["DELETED"];
                  group = "events.k8s.io";
                  mode = "watch";
                  name = "events";
                }
              ];
            };
            otlp = {
              protocols = {
                grpc = {endpoint = "\${env:K8S_POD_IP}:4317";};
                http = {endpoint = "\${env:K8S_POD_IP}:4318";};
              };
            };
          };
          service = {
            pipelines = {
              logs = {
                receivers = ["otlp" "k8sobjects"];
                processors = ["memory_limiter" "batch"];
                exporters = ["influxdb"];
              };
              metrics = {
                receivers = ["otlp" "k8s_cluster"];
                processors = ["memory_limiter" "batch"];
                exporters = ["influxdb"];
              };
              traces = {
                receivers = ["otlp"];
                processors = ["memory_limiter" "batch"];
                exporters = ["influxdb"];
              };
            };
          };
        };
      };
    }
  ];
}
