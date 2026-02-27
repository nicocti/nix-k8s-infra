{pkgs, ...}: let
  default = import ./default.nix {inherit pkgs;};
  kubectl = pkgs.lib.getExe pkgs.kubectl;
in {
  test = builtins.trace default.outputs.out default;

  applyGarageLayout = pkgs.writers.writeNuBin "applyGarageLayout" ''
    def --wrapped garage [...args] {
        ${kubectl} -n ${default.conf.garage.namespace} exec -i -c garage statefulsets/garage -- ./garage ...$args
    }

    # setup nodes layout if not already done:
    let nodes = (garage status) | detect columns -s 1 --guess
    if ($nodes | any {|node| $node.Zone | is-empty }) {
      for node in $nodes {
        let host = ${kubectl} -n ${default.conf.garage.namespace} get -o json pod $node.Hostname | from json | get spec.nodeName
        garage layout assign $node.ID -z par1 -c 100G -t $host
      }
      garage layout apply --version 1
    }

    # setup keys and buckets:
    let buckets = garage bucket list | detect columns --guess | if ($in | is-empty) { [] } else { get ($in | columns | get 2) }
    let keys = garage key list | detect columns --guess | if ($in | is-empty) { [] } else { get ($in | columns | get 2) }
    if not ("admin" in $keys) { garage key create admin }

    mut need_acl = false
    mut key = null
    if not ("${default.conf.influxdb.bucket.name}" in $keys) {
      $key = (garage key create ${default.conf.influxdb.bucket.name}
        | lines
        | where ($it | str contains ":")
        | parse "{key}:{value}"
        | str trim
        | transpose --header-row --as-record
      )
      $need_acl = true
    } else {
      $key = (garage key info --show-secret ${default.conf.influxdb.bucket.name}
        | lines
        | where ($it | str contains ":")
        | parse "{field}:{value}"
        | str trim
        | transpose --header-row --as-record
      )
    }
    let secret = (${kubectl} -n ${default.conf.influxdb.namespace} get secret ${default.conf.influxdb.bucket.secret} | complete)
    if ($key | is-not-empty) and ($secret.exit_code != 0) {
      (
      ${kubectl} -n ${default.conf.influxdb.namespace} create secret generic ${default.conf.influxdb.bucket.secret}
      --from-literal=access-key-id=($key."Key ID")
      --from-literal=secret-access-key=($key."Secret key")
      )
    }
    if not ("${default.conf.influxdb.bucket.name}" in $buckets) {
      garage bucket create ${default.conf.influxdb.bucket.name}
      $need_acl = true
    }
    if $need_acl {
      garage bucket allow --read --write ${default.conf.influxdb.bucket.name} --key ${default.conf.influxdb.bucket.name}
      garage bucket allow --read --write --owner ${default.conf.influxdb.bucket.name} --key admin
    }
  '';

  setupInfluxDB = pkgs.writers.writeNuBin "setupInfluxDB" ''
    def --wrapped influxdb3 [...args] {
        ${kubectl} -n ${default.conf.influxdb.namespace} exec deployments/influxdb -- influxdb3 ...$args
    }

    let admin = (
      ${kubectl} -n ${default.conf.influxdb.namespace} get secret admin-token -o json
      | from json
      | get data
      | get admin-token
      | base64 -d
      | from json
      | get token
    )
    let tokens = influxdb3 show tokens --token $admin | detect columns --guess -s 1
    let databases = influxdb3 show databases --token $admin | detect columns --guess -s 1 | get "iox::database"

    if not ("otel" in $databases) {
      influxdb3 create database --retention-period 30d otel --token $admin
    }
    if not ("otelco" in $tokens.name) {
      let token = (influxdb3 create token --permission "db:otel:read,write" --name otelco --token $admin
        | lines
        | where ($it | str contains "Token:")
        | parse "{key}:{value}"
        | get value
        | get 0
        | str trim
        | str substring 5..
      )
      ${kubectl} -n otel create secret generic influx-auth --from-literal=INFLUXDB_TOKEN=($token)
    }
    if not ("grafana" in $tokens.name) {
      let token = (influxdb3 create token --permission "db:*:read" --name grafana --token $admin
        | lines
        | where ($it | str contains "Token:")
        | parse "{key}:{value}"
        | get value
        | get 0
        | str trim
        | str substring 5..
      )
      ${kubectl} -n grafana create secret generic influx-auth --from-literal=INFLUXDB_TOKEN=($token)
    }
  '';
}
