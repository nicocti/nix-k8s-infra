{
  config,
}:
{
  name = "cilium";
  chart = "cilium";
  namespace = "cilium";
  repo = "https://helm.cilium.io/";
  version = "1.18.3";
  hash = "sha256-wMKbd2SR2+5LKBEPtm4vHJRkGwyzNEprjEG5QZD9s5E=";

  helmValues = {
    ingressController = {
      default = true;
      enabled = true;
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
      secretsNamespace = {
        create = true;
        name = "cilium-secrets";
        sync = true;
      };
    };
    operator = {
      replicas = 1;
      rollOutPods = true;
    };
    rollOutCiliumPods = true;
    bpf = {
      masquerade = true;
    };
    kubeProxyReplacement = true;
    hubble = {
      relay = {
        enabled = true;
      };
      ui = {
        enabled = true;
        ingress = {
          annotations = { };
          className = "cilium";
          enabled = true;
          hosts = [ "hubble.${config.domain}" ];
          labels = { };
          tls = [ { hosts = [ "hubble.${config.domain}" ]; } ];
        };
      };
    };
    k8sServiceHost = "${config.cilium.k8sApiAddr}";
    k8sServicePort = 6443;
    k8sClientRateLimit = {
      qps = 30;
      burst = 200;
    };
    l2announcements = {
      enabled = true;
    };
    externalIPs = {
      enabled = true;
    };
  };
  extraManifests = [
    {
      apiVersion = "cilium.io/v2alpha1";
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
