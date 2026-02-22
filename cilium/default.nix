{config}: let
  internalPodsCIDR = "10.42.0.0/16";
in {
  name = "cilium";
  chart = "cilium";
  namespace = "cilium";
  image = "oci://quay.io/cilium/charts/cilium";
  version = "1.19.0";
  hash = "sha256-4DjVw9ItefruZxpB4Tf4+zZimJcM5RXv3Cqhw/k3m9Q=";

  helmValues = {
    k8sServiceHost = "127.0.0.1";
    k8sServicePort = 6444;
    rollOutCiliumPods = true; # when configmap is updated
    kubeProxyReplacement = true;
    # Rely on native routing:
    routingMode = "native";
    ipv4NativeRoutingCIDR = internalPodsCIDR;
    autoDirectNodeRoutes = true;
    # Enforce eBPF:
    bpf = {
      masquerade = true;
      datapathMode = "netkit";
      enableTCX = true; # need to check if kernel supports it, otherwise falls back to classic TC
    };
    l2announcements = {
      enabled = true;
    };
    l2NeighDiscovery = {
      enabled = true;
    };
    enableLBIPAM = true;
    ipam = {
      mode = "cluster-pool";
      operator = {
        clusterPoolIPv4MaskSize = 24;
        clusterPoolIPv4PodCIDRList = [internalPodsCIDR];
      };
    };
    bandwidthManager = {
      enabled = true;
      bbr = true;
    };
    socketLB = {
      enabled = true;
    };
    operator = {
      replicas = 1;
      rollOutPods = true; # when configmap is updated
    };
    envoy = {
      enabled = true;
    };
    ingressController = {
      enabled = true;
      default = true;
      loadbalancerMode = "shared";
      defaultSecretNamespace = "cilium";
      defaultSecretName = "default-cert";
      service = {
        annotations = {
          "io.cilium/lb-ipam-ips" = "${config.cilium.rproxyIp}";
        };
      };
    };
    gatewayAPI = {
      enabled = true;
    };
    hubble = {
      enabled = true;
      relay = {
        enabled = true;
      };
      ui = {
        enabled = true;
        ingress = {
          annotations = {};
          className = "cilium";
          enabled = true;
          hosts = ["hubble.${config.domain}"];
          labels = {};
          tls = [{hosts = ["hubble.${config.domain}"];}];
        };
      };
    };
  };
  extraManifests = [
    {
      apiVersion = "cilium.io/v2";
      kind = "CiliumLoadBalancerIPPool";
      metadata = {
        name = "first-pool";
        namespace = "cilium";
      };
      spec = {
        blocks = [
          {
            start = "${config.cilium.ipPoolStart}";
            stop = "${config.cilium.ipPoolStop}";
          }
        ];
      };
    }
    {
      apiVersion = "cilium.io/v2alpha1";
      kind = "CiliumL2AnnouncementPolicy";
      metadata = {
        name = "default-l2-announcement-policy";
        namespace = "cilium";
      };
      spec = {
        externalIPs = true;
        loadBalancerIPs = true;
      };
    }
  ];
}
