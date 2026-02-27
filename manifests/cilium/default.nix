{config}: let
  internalPodsCIDR = "10.42.0.0/16";
in rec {
  name = "cilium";
  version = "1.19.1";
  namespace = "cilium";
  image = "oci://quay.io/cilium/charts/cilium";
  hash = "9/NgTLfOk1S2Em0MmCtworv7+v2w3zk608clR5oB/t8=";

  helmValues = {
    # Connect directly to local API server on the host
    k8sServiceHost = "127.0.0.1";
    k8sServicePort = 6444;
    # Roll out cilium agent pods automatically when configmap is updated
    rollOutCiliumPods = true;
    operator = {
      replicas = 1;
      rollOutPods = true; # when configmap is updated
    };

    ###########
    # INGRESS #
    ###########

    envoy.enabled = true;
    gatewayAPI.enabled = true;
    ingressController = {
      enabled = true;
      default = true;
      loadbalancerMode = "shared";
      defaultSecretNamespace = namespace;
      defaultSecretName = "default-cert";
      service.annotations."io.cilium/lb-ipam-ips" = "${config.cilium.rproxyIp}";
    };

    ###########
    # ROUTING #
    ###########

    # Full replacement of kube-proxy for maximum performance
    kubeProxyReplacement = true;
    # Fast socket-level load balancing (bypasses node networking), required for kubeProxyReplacement
    socketLB.enabled = true;
    # Rely on native routing for minimum overhead
    routingMode = "native";
    ipv4NativeRoutingCIDR = internalPodsCIDR;
    # Each individual node is made aware of all pod IPs of all other nodes and routes are inserted into
    # the Linux kernel routing table to represent this. Nodes must share a single L2 network (switch).
    autoDirectNodeRoutes = true;
    # Enable L2 announcements (ARP), making services visible and reachable on the LAN
    l2announcements.enabled = true;
    # Disable L2 announcements (ARP) for pod IPs (no traffic balancing available for l2announcements)
    l2podAnnouncements.enabled = false;
    # allows Cilium to assign IP addresses from CiliumLoadBalancerIPPool to services
    enableLBIPAM = true;

    ipam = {
      mode = "cluster-pool"; # default
      operator = {
        # IPv4 CIDR mask size to delegate to each nodes for IPAM (max 254 pods per node with /24)
        clusterPoolIPv4MaskSize = 24;
        # IPv4 CIDR mask which can be used for pods addressing
        clusterPoolIPv4PodCIDRList = [internalPodsCIDR];
      };
    };

    bpf = {
      masquerade = true; # eBPF-based masquerading instead of iptables
      datapathMode = "netkit"; # low overhead datapath (compared to veth)
      enableTCX = true; # need to check if kernel supports it, otherwise silently falls back to classic TC
    };

    # Manage bandwidth using BBR congestion control
    bandwidthManager = {
      enabled = true;
      bbr = true;
    };

    # Enable L2 neighbor discovery in the agent (need to make sure this makes sense in none XDP setups)
    l2NeighDiscovery.enabled = true;

    #################
    # OBSERVABILITY #
    #################

    hubble = {
      enabled = true;
      relay.enabled = true;
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
    # Define the IP pool for LoadBalancer services
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
    # Allow responding to ARP requests
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
