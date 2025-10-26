{}:{
  domain = "example.com";
  cilium = {
    rproxyIp = "192.268.0.101";
    k8sApiAddr = "192.168.0.10";
    ipPoolStart = "192.268.0.100";
    ipPoolStop = "192.268.0.200";
  };
  influxdb = {
    email = "mail@example.com";
  };
}